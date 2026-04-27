from datetime import datetime, timedelta, timezone
from app.db.connection import get_database
from bson import ObjectId
from app.models.analytics import (
    AnalyticsSummary,
    AchievementItem,
    WeeklyStats,
    MonthlyStats,
)



def _make_aware(dt: datetime) -> datetime:
    """Makes a naive datetime timezone-aware (assumes UTC)."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt

async def get_analytics_summary(user_id: str) -> AnalyticsSummary:
    db = get_database()
    now = datetime.now(timezone.utc)

    # Fetch user for their work hours setting
    user = await db["users"].find_one({"_id": ObjectId(user_id)})
    hours_per_task = 1.5
    if user and user.get("preferences"):
        daily_work_hours = user["preferences"].get("daily_work_hours", 8)
        # Assume user completes ~5 tasks per day on average
        hours_per_task = daily_work_hours / 5

    # Fetch all tasks for this user once
    tasks = await db["tasks"].find({"user_id": user_id}, {"_id": 0}).to_list(length=None)


    # ── Completion rates ──────────────────────────────────────────
    week_cutoff = now - timedelta(days=7)
    month_cutoff = now - timedelta(days=30)

    # A task "belongs" to the period by due_date if set, otherwise created_at,
    # so tasks without a due_date are still counted.
    def _task_date(t: dict) -> datetime:
        return _make_aware(t["due_date"] if t.get("due_date") else t["created_at"])

    week_tasks = [t for t in tasks if _task_date(t) >= week_cutoff]
    month_tasks = [t for t in tasks if _task_date(t) >= month_cutoff]

    week_completed = [t for t in week_tasks if t.get("status") == "completed"]
    month_completed = [t for t in month_tasks if t.get("status") == "completed"]

    weekly_rate = len(week_completed) / len(week_tasks) if week_tasks else 0.0
    monthly_rate = len(month_completed) / len(month_tasks) if month_tasks else 0.0

    # ── Weekly bar chart (Mon–Sun of the current week) ────────────
    # updated_at is the best proxy for "when was this task completed"
    week_start = (now - timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
        # timezone already inherited from now since now is aware
    )

    weekly_chart: list[float] = []
    for i in range(7):
        day_start = week_start + timedelta(days=i)
        day_end = day_start + timedelta(days=1)
        count = sum(
            1
            for t in tasks
            if t.get("completed_at")
            and day_start <= _make_aware(t["completed_at"]) < day_end  # FIXED: Added _make_aware()
        )
        weekly_chart.append(float(count))

    # ── Monthly line chart (Jan–Dec of the current year) ─────────
    completed_this_year = [
        _make_aware(t["completed_at"])
        for t in tasks
        if t.get("completed_at") and _make_aware(t["completed_at"]).year == now.year
    ]
    monthly_chart: list[float] = [
        float(sum(1 for ca in completed_this_year if ca.month == month))
        for month in range(1, 13)
    ]

    # ── Stat cards ────────────────────────────────────────────────
    n_week_done = len(week_completed)
    focus_hours = f"{n_week_done * hours_per_task:.1f}h"
    avg_time = f"{7 / n_week_done:.1f}d" if n_week_done > 0 else "–"

    n_month_done = len(month_completed)
    n_month_total = len(month_tasks)
    efficiency_pct = round(n_month_done / n_month_total * 100) if n_month_total > 0 else 0

    # ── Totals (for achievements) ─────────────────────────────────
    all_completed = [t for t in tasks if t.get("status") == "completed"]
    total_completed = len(all_completed)
    total_tasks = len(tasks)

    # ── Achievements ──────────────────────────────────────────────
    achievements: list[AchievementItem] = []
    if total_completed >= 1:
        achievements.append(
            AchievementItem(
                icon="🎯",
                title="First task completed!",
                subtitle="You're on your way.",
            )
        )
    if weekly_rate >= 0.8:
        achievements.append(
            AchievementItem(
                icon="🔥",
                title="Weekly streak",
                subtitle="80%+ completion this week.",
            )
        )
    if total_completed >= 10:
        achievements.append(
            AchievementItem(
                icon="⭐",
                title="Power user",
                subtitle="10 tasks completed.",
            )
        )

    return AnalyticsSummary(
        weekly_completion_rate=weekly_rate,
        monthly_completion_rate=monthly_rate,
        weekly_chart_data=weekly_chart,
        monthly_chart_data=monthly_chart,
        weekly_stats=WeeklyStats(focus_hours=focus_hours, avg_time=avg_time),
        monthly_stats=MonthlyStats(
            tasks_completed=str(n_month_done),
            efficiency=f"{efficiency_pct}%",
        ),
        achievements=achievements,
        total_completed=total_completed,
        total_tasks=total_tasks,
    )
