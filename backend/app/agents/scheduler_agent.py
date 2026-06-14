# app/agents/scheduler_agent.py
# Scheduler Agent — helps users plan and balance their workload

from langchain_core.tools import tool
from datetime import datetime, timezone, timedelta
from app.db.connection import get_database


# ─────────────────────────────────────────────────────────────────
# HELPER — safe timezone normalization
# Always use this instead of .replace(tzinfo=...) on unknown datetimes
# .replace() overwrites tzinfo even if already set → wrong times
# .astimezone() converts correctly regardless of existing tzinfo
# ─────────────────────────────────────────────────────────────────
def _to_utc(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)   # naive → assume UTC
    return dt.astimezone(timezone.utc)            # aware → convert to UTC


# ─────────────────────────────────────────────────────────────────
# Tool 1 — Summarize Day
# ─────────────────────────────────────────────────────────────────
def get_summarize_day_tool(user_id: str):
    @tool
    async def summarize_day() -> str:
        """
        Give a summary of the user's day — tasks, progress, deadlines.
        Use when user says: 'summarize my day', 'how am I doing today',
        'what's my day look like', 'daily summary', 'today's overview',
        'what's on my plate today', 'my schedule today'.
        """
        try:
            db = get_database()
            now = datetime.now(timezone.utc)
            day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)

            all_tasks = await db["tasks"].find(
                {"user_id": user_id}, {"_id": 0}
            ).to_list(length=None)

            
            due_today = [
                t for t in all_tasks
                if t.get("due_date") and isinstance(t["due_date"], datetime)
                and day_start <= _to_utc(t["due_date"]) < day_end
            ]

            completed_today = [
                t for t in all_tasks
                if t.get("completed_at")
                and isinstance(t["completed_at"], datetime)
                and day_start <= _to_utc(t["completed_at"]) < day_end
            ]

            pending = [t for t in all_tasks if t.get("status") == "pending"]
            in_progress = [t for t in all_tasks if t.get("status") == "in_progress"]

            lines = [f"📋 Day Summary — {now.strftime('%A, %B %d')}"]
            lines.append(f"\n✅ Completed today: {len(completed_today)}")
            lines.append(f"⏳ In progress: {len(in_progress)}")
            lines.append(f"📌 Pending: {len(pending)}")

            if due_today:
                lines.append(f"\n📅 Due today ({len(due_today)}):")
                for t in due_today[:5]:
                    status_icon = "✓" if t.get("status") == "completed" else "○"
                    lines.append(f"  {status_icon} {t['title']}")

            if not pending and completed_today:
                lines.append("\n🎉 Great work! All tasks completed!")
            elif len(pending) > 5:
                lines.append("\n💡 Tip: Focus on high priority tasks first.")

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to summarize day: {str(e)}"

    return summarize_day


# ─────────────────────────────────────────────────────────────────
# Tool 2 — Prioritize Tasks
# ─────────────────────────────────────────────────────────────────
def get_prioritize_tasks_tool(user_id: str):
    @tool
    async def prioritize_tasks() -> str:
        """
        Suggest which tasks to focus on first based on priority and deadline.
        Use when user says: 'what should I do first', 'prioritize my tasks',
        'what's most important', 'help me decide what to work on',
        'what task should I start with', 'organize my tasks'.
        """
        try:
            db = get_database()
            now = datetime.now(timezone.utc)

            tasks = await db["tasks"].find({
                "user_id": user_id,
                "status": {"$ne": "completed"},
            }, {"_id": 0}).to_list(length=50)

            if not tasks:
                return "You have no pending tasks. You're all caught up! 🎉"

            def score_task(t):
                score = 0
                priority_scores = {"high": 30, "medium": 15, "low": 5}
                score += priority_scores.get(t.get("priority", "medium"), 10)
                if t.get("due_date") and isinstance(t["due_date"], datetime):
                    due = _to_utc(t["due_date"])   # BUG FIX: safe conversion
                    hours_left = (due - now).total_seconds() / 3600
                    if hours_left < 0:
                        score += 50   # overdue — top priority
                    elif hours_left < 24:
                        score += 40   # due today
                    elif hours_left < 72:
                        score += 20   # due this week
                return score

            scored = sorted(tasks, key=score_task, reverse=True)
            top = scored[:5]

            lines = ["🎯 Recommended task order:"]
            for i, t in enumerate(top, 1):
                due_str = ""
                if t.get("due_date") and isinstance(t["due_date"], datetime):
                    due = _to_utc(t["due_date"])   # BUG FIX
                    hours = (due - now).total_seconds() / 3600
                    if hours < 0:
                        due_str = " ⚠️ OVERDUE"
                    elif hours < 24:
                        due_str = " (due today)"
                    else:
                        due_str = f" (due {due.strftime('%b %d')})"
                lines.append(
                    f"{i}. {t['title']} [{t.get('priority', 'medium')} priority]{due_str}"
                )

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to prioritize tasks: {str(e)}"

    return prioritize_tasks


# ─────────────────────────────────────────────────────────────────
# Tool 3 — Workload Balance Check
# ─────────────────────────────────────────────────────────────────
def get_workload_balance_tool(user_id: str):
    @tool
    async def check_workload_balance() -> str:
        """
        Check if the user's workload is balanced and sustainable.
        Use when user says: 'am I overloaded', 'is my workload ok',
        'check my workload', 'too many tasks', 'am I overwhelmed',
        'work life balance', 'am I burning out'.
        """
        try:
            db = get_database()
            now = datetime.now(timezone.utc)

            tasks = await db["tasks"].find({
                "user_id": user_id,
                "status": {"$ne": "completed"},
            }, {"_id": 0}).to_list(length=None)

            total_pending = len(tasks)
            high_priority = len([t for t in tasks if t.get("priority") == "high"])

            overdue = len([
                t for t in tasks
                if t.get("due_date")
                and isinstance(t["due_date"], datetime)
                and _to_utc(t["due_date"]) < now   # BUG FIX
            ])

            if total_pending == 0:
                status = "🟢 Light — No pending tasks"
                advice = "Great time to plan ahead or take a break!"
            elif total_pending <= 5 and overdue == 0:
                status = "🟢 Balanced — Manageable workload"
                advice = "You're in good shape. Keep going!"
            elif total_pending <= 10 and overdue <= 2:
                status = "🟡 Moderate — Getting busy"
                advice = "Focus on high priority tasks first."
            else:
                status = "🔴 Heavy — Risk of burnout"
                advice = "Consider delegating or rescheduling some tasks."

            lines = [
                f"⚖️ Workload Status: {status}",
                f"\n📊 Overview:",
                f"  • Total pending: {total_pending}",
                f"  • High priority: {high_priority}",
                f"  • Overdue: {overdue}",
                f"\n💡 {advice}",
            ]

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to check workload: {str(e)}"

    return check_workload_balance


# ─────────────────────────────────────────────────────────────────
# Tool 4 — Find Free Slots
# ─────────────────────────────────────────────────────────────────
def get_free_slots_tool(user_id: str):
    @tool
    async def find_free_slots(hours_needed: float = 2.0) -> str:
        """
        Suggest when the user could work on tasks based on their schedule.
        Use when user says: 'when can I work on this', 'find me time',
        'when am I free', 'schedule time for', 'block time for task'.

        Parameters:
        - hours_needed: how many hours the user needs (default 2)
        """
        try:
            now = datetime.now(timezone.utc)
            current_hour = now.hour

            if current_hour < 9:
                slots = ["9:00 AM - 11:00 AM", "2:00 PM - 4:00 PM", "7:00 PM - 9:00 PM"]
            elif current_hour < 12:
                slots = ["Now until lunch", "2:00 PM - 4:00 PM", "7:00 PM - 9:00 PM"]
            elif current_hour < 14:
                slots = ["2:00 PM - 4:00 PM", "5:00 PM - 7:00 PM", "8:00 PM - 10:00 PM"]
            elif current_hour < 18:
                slots = ["Now - Evening", "7:00 PM - 9:00 PM", "9:00 PM - 11:00 PM"]
            else:
                slots = ["Now - Tonight", "Tomorrow 9:00 AM - 11:00 AM", "Tomorrow 2:00 PM - 4:00 PM"]

            lines = [f"⏰ Suggested time slots for {hours_needed}h of work:"]
            for i, slot in enumerate(slots[:3], 1):
                lines.append(f"  {i}. {slot}")
            lines.append("\n💡 Tip: Schedule your most important task during your peak energy hours.")

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to find free slots: {str(e)}"

    return find_free_slots


# ─────────────────────────────────────────────────────────────────
# Export all Scheduler Agent tools
# ─────────────────────────────────────────────────────────────────
def get_scheduler_agent_tools(user_id: str) -> list:
    return [
        get_summarize_day_tool(user_id),
        get_prioritize_tasks_tool(user_id),
        get_workload_balance_tool(user_id),
        get_free_slots_tool(user_id),
    ]