# app/agents/proactive_agent.py
#
# ✅ FIX: under the new session-based chat schema, the old _save_briefing
# pushed into {"user_id": user_id} with no session_id — that pattern is
# now incompatible: it would create an orphaned conversation document
# with no session_id field, which never shows up in the sidebar/session
# list. Fixed by giving briefings their own dedicated, deterministic
# session ("briefing-{user_id}") so every morning's briefing lands in
# ONE consistent "Daily Briefings" chat instead of vanishing.

import uuid
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from datetime import datetime, timezone, timedelta
from app.db.connection import get_database
from app.config import settings

_proactive_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.LIGHTWEIGHT_MODEL,
    temperature=0.5,
    max_tokens=512,
    timeout=20,
    max_retries=2,
)

def _to_utc(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

async def _gather_user_context(user_id: str) -> dict:
    db = get_database()
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)
    tomorrow_end = today_end + timedelta(days=1)

    tasks = await db["tasks"].find({
        "user_id": user_id,
        "status": {"$ne": "completed"},
    }, {"_id": 0}).to_list(length=100)

    overdue, due_today, due_tomorrow, high_priority = [], [], [], []

    for t in tasks:
        due = t.get("due_date")
        if not due or not isinstance(due, datetime):
            if t.get("priority") == "high":
                high_priority.append(t["title"])
            continue
        due_utc = _to_utc(due)
        if due_utc < today_start:
            overdue.append(t["title"])
        elif today_start <= due_utc < today_end:
            due_today.append(t["title"])
        elif today_end <= due_utc < tomorrow_end:
            due_tomorrow.append(t["title"])
        if t.get("priority") == "high" and due_utc >= today_start:
            high_priority.append(t["title"])

    week_start = (now - timedelta(days=7)).strftime("%Y-%m-%d")
    today_str = now.strftime("%Y-%m-%d")
    records = await db["analytics"].find({
        "user_id": user_id,
        "date": {"$gte": week_start, "$lte": today_str},
    }).to_list(length=7)
    total_completed_week = sum(r.get("tasks_completed", 0) for r in records)

    return {
        "date_str": now.strftime("%A, %B %d"),
        "overdue": overdue[:5],
        "due_today": due_today[:5],
        "due_tomorrow": due_tomorrow[:3],
        "high_priority": list(set(high_priority))[:3],
        "total_pending": len(tasks),
        "completed_this_week": total_completed_week,
    }

async def _generate_briefing_text(context: dict) -> str:
    parts = [f"Today is {context['date_str']}."]
    if context["overdue"]:
        parts.append(f"OVERDUE tasks: {', '.join(context['overdue'])}")
    else:
        parts.append("No overdue tasks.")
    if context["due_today"]:
        parts.append(f"Due today: {', '.join(context['due_today'])}")
    else:
        parts.append("Nothing due today.")
    if context["due_tomorrow"]:
        parts.append(f"Due tomorrow: {', '.join(context['due_tomorrow'])}")
    if context["high_priority"]:
        parts.append(f"High priority tasks: {', '.join(context['high_priority'])}")
    parts.append(f"Total pending tasks: {context['total_pending']}")
    parts.append(f"Tasks completed this week: {context['completed_this_week']}")

    prompt = f"""You are CoCo, a friendly AI productivity assistant inside Cognify.
Generate a short, motivating morning briefing for this student/freelancer.

User's current situation:
{chr(10).join(parts)}

Instructions:
- Start with a warm greeting and today's date
- Mention overdue tasks FIRST if any (be firm but kind)
- List what's due today clearly
- Give one specific productivity tip based on their situation
- End with a short motivating line
- Keep it under 150 words total
- Use plain text with minimal emoji (2-3 max)
- Sound like a helpful friend, not a robot"""

    try:
        response = await _proactive_llm.ainvoke([
            SystemMessage(content="You are CoCo, a concise and friendly productivity assistant."),
            HumanMessage(content=prompt),
        ])
        return response.content.strip()
    except Exception:
        lines = [f"Good morning! Here's your briefing for {context['date_str']}."]
        if context["overdue"]:
            lines.append(f"⚠️ {len(context['overdue'])} overdue task(s) — tackle these first.")
        if context["due_today"]:
            lines.append(f"📅 Due today: {', '.join(context['due_today'])}")
        if not context["overdue"] and not context["due_today"]:
            lines.append("✅ No urgent deadlines today. Great time to get ahead!")
        lines.append("You've got this! 💪")
        return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────
# ✅ NEW: dedicated, deterministic session for all of a user's briefings
# ─────────────────────────────────────────────────────────────────
async def _get_or_create_briefing_session(user_id: str) -> str:
    """
    Briefings always go into ONE dedicated session per user —
    "Daily Briefings" — rather than scattering across random new
    chats or landing in an orphaned schema-less document. The id is
    deterministic (derived from user_id, not uuid4) so re-running this
    never creates duplicates — it always finds the same session.
    """
    db = get_database()
    session_id = f"briefing-{user_id}"

    existing = await db["conversations"].find_one({
        "user_id": user_id,
        "session_id": session_id,
    })
    if existing:
        return session_id

    await db["conversations"].insert_one({
        "session_id": session_id,
        "user_id": user_id,
        "title": "Daily Briefings",
        "messages": [],
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    })
    return session_id


async def _save_briefing(user_id: str, briefing_text: str) -> None:
    db = get_database()
    now = datetime.now(timezone.utc)
    notification = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "title": "☀️ Good morning! Your daily briefing",
        "message": briefing_text,
        "type": "proactive",
        "is_read": False,
        "is_triggered": True,
        "triggered_at": now,
        "task_id": None,
        "remind_at": None,
        "created_at": now,
    }
    await db["notifications"].insert_one(notification)

    # ✅ FIX: scoped to the dedicated briefing session_id, not a bare
    # {"user_id": user_id} filter — that pattern is incompatible with
    # the new per-session document schema.
    session_id = await _get_or_create_briefing_session(user_id)

    message = {
        "role": "assistant",
        "content": briefing_text,
        "source": "proactive",
        "intent": "morning_briefing",
        "timestamp": now,
    }
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {
            "$push": {"messages": message},
            "$set": {"updated_at": now},
        },
    )


async def generate_morning_briefing(user_id: str) -> bool:
    try:
        db = get_database()
        now = datetime.now(timezone.utc)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        existing = await db["notifications"].count_documents({
            "user_id": user_id,
            "type": "proactive",
            "created_at": {"$gte": today_start},
        })
        if existing > 0:
            return False

        task_count = await db["tasks"].count_documents({"user_id": user_id})
        if task_count == 0:
            return False

        context = await _gather_user_context(user_id)
        briefing_text = await _generate_briefing_text(context)
        await _save_briefing(user_id, briefing_text)
        print(f"☀️ Morning briefing sent to user {user_id[:8]}...")
        return True
    except Exception as e:
        print(f"❌ Proactive briefing failed for {user_id}: {str(e)}")
        return False

async def run_morning_briefings_for_all() -> None:
    db = get_database()
    user_ids = await db["tasks"].distinct("user_id")
    sent, skipped = 0, 0
    for user_id in user_ids:
        result = await generate_morning_briefing(user_id)
        if result:
            sent += 1
        else:
            skipped += 1
    print(f"☀️ Morning briefings done — sent: {sent}, skipped: {skipped}")