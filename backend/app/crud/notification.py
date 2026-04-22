import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional
from app.db.connection import get_database
from app.models.notification import NotificationCreate, NotificationResponse


async def setup_indexes() -> None:
    db = get_database()
    col = db["notifications"]
    await col.create_index("user_id")
    await col.create_index([("user_id", 1), ("is_read", 1)])
    await col.create_index([("user_id", 1), ("created_at", -1)])
    await col.create_index("remind_at", sparse=True)
    await col.create_index(                                    # ← ADDED
        [("type", 1), ("remind_at", 1), ("is_triggered", 1)]  # ← ADDED
    )                                                          # ← ADDED


def _to_response(doc: dict) -> NotificationResponse:
    doc.pop("_id", None)
    return NotificationResponse(**doc)


async def create_notification(data: NotificationCreate, user_id: str) -> NotificationResponse:
    db = get_database()
    doc = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "title": data.title,
        "message": data.message,
        "type": data.type,
        "is_read": False,
        "is_triggered": False,          # ← ADDED
        "triggered_at": None,           # ← ADDED
        "task_id": data.task_id,
        "remind_at": data.remind_at,
        "created_at": datetime.now(timezone.utc),
    }
    await db["notifications"].insert_one(doc)
    doc.pop("_id", None)
    return NotificationResponse(**doc)


async def get_notifications(
    user_id: str,
    unread_only: bool = False,
    skip: int = 0,
    limit: int = 20,
) -> dict:
    db = get_database()
    query: dict = {"user_id": user_id}
    if unread_only:
        query["is_read"] = False
    total = await db["notifications"].count_documents(query)
    cursor = db["notifications"].find(query).sort("created_at", -1).skip(skip).limit(limit)
    docs = await cursor.to_list(length=limit)
    return {
        "notifications": [_to_response(d) for d in docs],
        "total": total,
        "page": skip // limit + 1,
        "page_size": limit,
        "total_pages": max(1, (total + limit - 1) // limit),
    }


async def get_unread_count(user_id: str) -> int:
    db = get_database()
    return await db["notifications"].count_documents(
        {"user_id": user_id, "is_read": False}
    )


async def mark_as_read(notification_id: str, user_id: str) -> Optional[NotificationResponse]:
    db = get_database()
    result = await db["notifications"].find_one_and_update(
        {"id": notification_id, "user_id": user_id},
        {"$set": {"is_read": True}},
        return_document=True,
    )
    return _to_response(result) if result else None


async def mark_all_read(user_id: str) -> int:
    db = get_database()
    result = await db["notifications"].update_many(
        {"user_id": user_id, "is_read": False},
        {"$set": {"is_read": True}},
    )
    return result.modified_count


async def delete_notification(notification_id: str, user_id: str) -> bool:
    db = get_database()
    result = await db["notifications"].delete_one(
        {"id": notification_id, "user_id": user_id}
    )
    return result.deleted_count > 0


async def delete_multiple(notification_ids: list[str], user_id: str) -> int:
    db = get_database()
    result = await db["notifications"].delete_many({
        "id": {"$in": notification_ids},
        "user_id": user_id,
    })
    return result.deleted_count


async def mark_multiple_as_read(notification_ids: list[str], user_id: str) -> int:
    db = get_database()
    result = await db["notifications"].update_many(
        {"id": {"$in": notification_ids}, "user_id": user_id},
        {"$set": {"is_read": True}},
    )
    return result.modified_count


async def get_upcoming_reminders(
    user_id: str, hours_ahead: int = 24
) -> list[NotificationResponse]:
    db = get_database()
    now = datetime.now(timezone.utc)
    until = now + timedelta(hours=hours_ahead)
    cursor = db["notifications"].find({
        "user_id": user_id,
        "type": "reminder",
        "remind_at": {"$gte": now, "$lte": until},
        "is_triggered": False,          # ← ADDED
    }).sort("remind_at", 1)
    docs = await cursor.to_list(length=50)
    return [_to_response(d) for d in docs]


async def snooze_reminder(
    notification_id: str, user_id: str, minutes: int
) -> Optional[NotificationResponse]:
    db = get_database()
    doc = await db["notifications"].find_one({
        "id": notification_id,
        "user_id": user_id,
        "type": "reminder"
    })
    if not doc:
        return None
    current = doc.get("remind_at")
    if current is None:
        return None
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    new_remind_at = current + timedelta(minutes=minutes)
    result = await db["notifications"].find_one_and_update(
        {"id": notification_id, "user_id": user_id},
        {"$set": {
            "remind_at": new_remind_at,
            "is_read": False,
            "is_triggered": False,      # ← ADDED (reset so it triggers again)
        }},
        return_document=True,
    )
    return _to_response(result) if result else None


# ── Called by scheduler every minute ─────────────────────────────────────────
async def process_due_reminders() -> int:
    """Find reminders whose remind_at has passed and mark them triggered"""
    db = get_database()
    now = datetime.now(timezone.utc)

    cursor = db["notifications"].find({
        "type": "reminder",
        "remind_at": {"$lte": now},
        "is_triggered": False,
    })
    due = await cursor.to_list(length=100)

    if not due:
        return 0

    # Mark all as triggered
    ids = [r["id"] for r in due]
    await db["notifications"].update_many(
        {"id": {"$in": ids}},
        {"$set": {
            "is_triggered": True,
            "triggered_at": now,
            "is_read": False,           # ensure unread so user sees it
        }}
    )

    for reminder in due:
        print(f"🔔 REMINDER TRIGGERED: {reminder['title']}")

    return len(due)