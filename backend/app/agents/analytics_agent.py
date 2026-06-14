# app/agents/analytics_agent.py
# Analytics Agent — reads user's productivity data and provides insights

from langchain_core.tools import tool
from datetime import datetime, timezone, timedelta
from app.db.connection import get_database
from app.crud.analytics import get_analytics_summary


# ─────────────────────────────────────────────────────────────────
# Tool 1 — Get Productivity Score
# ─────────────────────────────────────────────────────────────────
def get_productivity_score_tool(user_id: str):
    @tool
    async def get_productivity_score() -> str:
        """
        Get the user's current productivity score and stats.
        Use when user says: 'how productive am I', 'my productivity score',
        'how am I doing', 'productivity stats', 'my performance',
        'am I being productive', 'show my stats'.
        """
        try:
            summary = await get_analytics_summary(user_id)

            weekly_pct = round(summary.weekly_completion_rate * 100)
            monthly_pct = round(summary.monthly_completion_rate * 100)

            # Productivity level
            if weekly_pct >= 80:
                level = "🔥 Excellent"
            elif weekly_pct >= 60:
                level = "✅ Good"
            elif weekly_pct >= 40:
                level = "⚠️ Moderate"
            else:
                level = "📉 Needs Improvement"

            lines = [
                f"📊 Your Productivity Report",
                f"\n{level}",
                f"\nThis week: {weekly_pct}% completion rate",
                f"This month: {monthly_pct}% completion rate",
                f"\n📈 Stats:",
                f"  • Focus hours this week: {summary.weekly_stats.focus_hours}",
                f"  • Avg task time: {summary.weekly_stats.avg_time}",
                f"  • Total completed: {summary.total_completed}/{summary.total_tasks}",
            ]

            if summary.achievements:
                lines.append("\n🏆 Achievements:")
                for a in summary.achievements[:3]:
                    lines.append(f"  {a.icon} {a.title}")

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to get productivity score: {str(e)}"

    return get_productivity_score


# ─────────────────────────────────────────────────────────────────
# Tool 2 — Weekly Summary
# ─────────────────────────────────────────────────────────────────
def get_weekly_summary_tool(user_id: str):
    @tool
    async def get_weekly_summary() -> str:
        """
        Get a summary of what the user accomplished this week.
        Use when user says: 'weekly summary', 'how was my week',
        'what did I accomplish this week', 'week review',
        'my week in review', 'weekly report'.
        """
        try:
            db = get_database()
            now = datetime.now(timezone.utc)
            week_start = (now - timedelta(days=now.weekday())).replace(
                hour=0, minute=0, second=0, microsecond=0
            )

            # Tasks this week
            all_tasks = await db["tasks"].find(
                {"user_id": user_id}, {"_id": 0}
            ).to_list(length=None)

            created_this_week = [
                t for t in all_tasks
                if isinstance(t.get("created_at"), datetime) and
                (t["created_at"].replace(tzinfo=timezone.utc)
                 if t["created_at"].tzinfo is None
                 else t["created_at"]) >= week_start
            ]

            completed_this_week = [
                t for t in all_tasks
                if t.get("status") == "completed" and
                isinstance(t.get("completed_at"), datetime) and
                (t["completed_at"].replace(tzinfo=timezone.utc)
                 if t["completed_at"].tzinfo is None
                 else t["completed_at"]) >= week_start
            ]

            # Category breakdown
            categories = {}
            for t in completed_this_week:
                cat = t.get("category", "general")
                categories[cat] = categories.get(cat, 0) + 1

            lines = [
                f"📅 Week of {week_start.strftime('%B %d')}",
                f"\n✅ Completed: {len(completed_this_week)} tasks",
                f"📝 Created: {len(created_this_week)} tasks",
            ]

            if categories:
                lines.append("\n📂 By category:")
                for cat, count in sorted(categories.items(),
                                         key=lambda x: x[1], reverse=True):
                    lines.append(f"  • {cat.capitalize()}: {count}")

            # Trend
            if len(completed_this_week) >= len(created_this_week) * 0.7:
                lines.append("\n🌟 Great week! You completed most of what you planned.")
            elif len(completed_this_week) > 0:
                remaining = len(created_this_week) - len(completed_this_week)
                lines.append(f"\n💪 Good progress! {remaining} tasks still pending.")
            else:
                lines.append("\n💡 This week is just getting started. You got this!")

            return "\n".join(lines)

        except Exception as e:
            return f"Failed to get weekly summary: {str(e)}"

    return get_weekly_summary


# ─────────────────────────────────────────────────────────────────
# Tool 3 — Most Active Hour
# ─────────────────────────────────────────────────────────────────
def get_most_active_hour_tool(user_id: str):
    @tool
    async def get_most_active_hour() -> str:
        """
        Find when the user is most productive during the day.
        Use when user says: 'when am I most productive', 'my peak hours',
        'best time to work', 'when do I work best', 'my productive time'.
        """
        try:
            db = get_database()

            completed_tasks = await db["tasks"].find({
                "user_id": user_id,
                "status": "completed",
                "completed_at": {"$exists": True},
            }, {"_id": 0, "completed_at": 1}).to_list(length=None)

            if not completed_tasks:
                return "Not enough data yet. Complete more tasks to see your peak hours!"

            # Count completions by hour
            hour_counts = {}
            for t in completed_tasks:
                if isinstance(t.get("completed_at"), datetime):
                    dt = t["completed_at"]
                    if dt.tzinfo is None:
                        dt = dt.replace(tzinfo=timezone.utc)
                    hour = dt.hour
                    hour_counts[hour] = hour_counts.get(hour, 0) + 1

            if not hour_counts:
                return "Not enough data yet to determine peak hours."

            # Find peak hour
            peak_hour = max(hour_counts, key=hour_counts.get)
            peak_count = hour_counts[peak_hour]

            # Format hour
            if peak_hour == 0:
                hour_str = "12:00 AM"
            elif peak_hour < 12:
                hour_str = f"{peak_hour}:00 AM"
            elif peak_hour == 12:
                hour_str = "12:00 PM"
            else:
                hour_str = f"{peak_hour - 12}:00 PM"

            # Time of day label
            if 5 <= peak_hour < 12:
                period = "morning person 🌅"
            elif 12 <= peak_hour < 17:
                period = "afternoon worker ☀️"
            elif 17 <= peak_hour < 21:
                period = "evening worker 🌆"
            else:
                period = "night owl 🦉"

            return (
                f"⏰ Your Peak Productivity Hour: {hour_str}\n"
                f"You're a {period}!\n"
                f"You've completed {peak_count} tasks during this hour.\n\n"
                f"💡 Schedule your most important tasks around {hour_str} "
                f"for maximum productivity."
            )

        except Exception as e:
            return f"Failed to get active hours: {str(e)}"

    return get_most_active_hour


# ─────────────────────────────────────────────────────────────────
# Export all Analytics Agent tools
# ─────────────────────────────────────────────────────────────────
def get_analytics_agent_tools(user_id: str) -> list:
    """Returns all analytics agent tools bound to this user's ID"""
    return [
        get_productivity_score_tool(user_id),
        get_weekly_summary_tool(user_id),
        get_most_active_hour_tool(user_id),
    ]