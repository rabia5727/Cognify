"""
Proactive notification logic.
Called on app open (refresh) and after milestone completion.
Avoids duplicate notifications by checking recent ones before inserting.
"""

import re
import uuid
from datetime import datetime, timezone, timedelta
from app.db.connection import get_database


def _parse_due_time(due_time_str: str) -> tuple[int, int] | None:
    """Parse '6:40pm', '10:00', etc. → (hour_24, minute). Returns None on failure."""
    match = re.match(r'(\d+):(\d+)\s*(am|pm)?', due_time_str.strip(), re.IGNORECASE)
    if not match:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    ampm = (match.group(3) or '').lower()
    if ampm == 'pm' and hour != 12:
        hour += 12
    elif ampm == 'am' and hour == 12:
        hour = 0
    return hour, minute


def _is_truly_overdue(due: datetime, due_time_str: str | None, now: datetime) -> bool:
    """
    True only when:
      - due_date is before today, OR
      - due_date is today AND due_time is set AND that time has already passed.
    Today-tasks with no due_time are never considered overdue.
    """
    today = now.date()
    due_date = due.date()

    if due_date < today:
        return True

    if due_date == today and due_time_str:
        parsed = _parse_due_time(due_time_str)
        if parsed:
            hour, minute = parsed
            due_datetime = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
            return now > due_datetime

    return False


async def _already_notified(db, user_id: str, notif_type: str, ref_id: str) -> bool:
    """Return True if a notification of this type for ref_id was created in the last 24h."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    count = await db["notifications"].count_documents({
        "user_id": user_id,
        "type": notif_type,
        "task_id": ref_id,
        "created_at": {"$gte": cutoff},
    })
    return count > 0


async def _insert(db, user_id: str, title: str, message: str, notif_type: str, ref_id: str | None = None):
    doc = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "is_read": False,
        "task_id": ref_id,
        "remind_at": None,
        "created_at": datetime.now(timezone.utc),
    }
    await db["notifications"].insert_one(doc)


# ── Called on app open ─────────────────────────────────────────────────────────

async def check_due_tasks(user_id: str) -> int:
    """
    Scans all pending/in-progress tasks for this user.
    Creates due_soon (within 24h) or overdue notifications.
    Returns count of new notifications created.
    """
    db = get_database()
    now = datetime.now(timezone.utc)
    soon = now + timedelta(hours=24)

    cursor = db["tasks"].find({
        "user_id": user_id,
        "status": {"$in": ["pending", "in_progress"]},
        "due_date": {"$ne": None},
    })
    tasks = await cursor.to_list(length=200)

    created = 0
    for task in tasks:
        due = task.get("due_date")
        if due is None:
            continue
        if due.tzinfo is None:
            due = due.replace(tzinfo=timezone.utc)

        task_id = task.get("id", str(task.get("_id", "")))
        title_text = task.get("title", "A task")
        due_time_str = task.get("due_time")  # e.g. "6:40pm" or None

        overdue = _is_truly_overdue(due, due_time_str, now)

        if overdue:
            if not await _already_notified(db, user_id, "overdue", task_id):
                await _insert(
                    db, user_id,
                    title="Task overdue",
                    message=f'"{title_text}" is past its due date. Complete it now to stay on track.',
                    notif_type="overdue",
                    ref_id=task_id,
                )
                created += 1

        elif due <= soon:
            # Due within 24 hours but not overdue
            hours_left = int((due - now).total_seconds() // 3600)
            label = f"{hours_left}h" if hours_left > 0 else "less than 1h"
            if not await _already_notified(db, user_id, "due_soon", task_id):
                await _insert(
                    db, user_id,
                    title="Task due soon",
                    message=f'"{title_text}" is due in {label}. Don\'t let it slip!',
                    notif_type="due_soon",
                    ref_id=task_id,
                )
                created += 1

    return created


# ── Called after complete_milestone ───────────────────────────────────────────

_PROGRESS_THRESHOLDS = [
    (100.0, "achievement", "Workspace complete! 🎉", "You finished every milestone. Outstanding work!"),
    (75.0,  "general",     "You're almost there! 🔥", "Just a few milestones left. Push through!"),
    (50.0,  "general",     "Halfway there! 💪",        "You've completed half the milestones. Keep it up!"),
]


async def check_workflow_progress(
    workflow_id: str,
    user_id: str,
    workflow_title: str,
    progress: float,
) -> bool:
    """
    After a milestone is completed, check if progress crossed a threshold
    and fire a motivational notification. Returns True if one was created.
    """
    db = get_database()

    for threshold, notif_type, title, base_message in _PROGRESS_THRESHOLDS:
        if progress >= threshold:
            # Check if we already sent this threshold notification for this workflow
            cutoff = datetime.now(timezone.utc) - timedelta(days=30)
            existing = await db["notifications"].count_documents({
                "user_id": user_id,
                "type": notif_type,
                "task_id": workflow_id,
                "title": title,
                "created_at": {"$gte": cutoff},
            })
            if existing == 0:
                await _insert(
                    db, user_id,
                    title=title,
                    message=f'"{workflow_title}" — {base_message}',
                    notif_type=notif_type,
                    ref_id=workflow_id,
                )
                return True
            break  # Only fire highest crossed threshold

    return False
