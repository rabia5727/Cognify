from datetime import datetime, timedelta, timezone
from app.db.connection import get_database
from app.models.analytics import (
    AnalyticsSummary,
    AnalyticsDailyRecord,
    AchievementItem,
    WeeklyStats,
    MonthlyStats,
)

MAX_TASK_HOURS = 4.0

def _make_aware(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _calc_hours_per_task(tasks: list) -> float:
    completed_with_time = [
        t for t in tasks
        if t.get("status") == "completed"
        and t.get("completed_at")
        and t.get("created_at")
    ]
    if not completed_with_time:
        return 1.5

    total_hours = sum(
    min(
        (_make_aware(t["completed_at"]) - _make_aware(t["created_at"])).total_seconds() / 3600,
        MAX_TASK_HOURS,
    )
    for t in completed_with_time
)
    return total_hours / len(completed_with_time)


# ── Setup indexes ─────────────────────────────────────────────────

async def setup_indexes() -> None:
    db = get_database()
    col = db["analytics"]
    await col.create_index([("user_id", 1), ("date", -1)])
    await col.create_index([("user_id", 1), ("date", 1)], unique=True)


# ── Record daily snapshot ─────────────────────────────────────────

async def record_daily_snapshot(user_id: str) -> None:
    """
    Called whenever a task is completed or created.
    Upserts today's analytics record for the user.
    """
    db = get_database()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Fetch today's tasks
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    tasks = await db["tasks"].find({"user_id": user_id}, {"_id": 0}).to_list(length=None)

    # Tasks created today
    created_today = [
        t for t in tasks
        if _make_aware(t["created_at"]) >= day_start
    ]

    # Tasks completed today
    completed_today = [
        t for t in tasks
        if t.get("completed_at")
        and day_start <= _make_aware(t["completed_at"]) < day_end
    ]

    # Focus hours = sum of actual time per task completed today
    focus_hours = sum(
    min(
        (_make_aware(t["completed_at"]) - _make_aware(t["created_at"])).total_seconds() / 3600,
        MAX_TASK_HOURS,
    )
    for t in completed_today
    if t.get("created_at")
)

    # Avg completion time
    avg_completion_time = (
        focus_hours / len(completed_today) if completed_today else 0.0
    )

    # Completion rate for today
    total_due_today = [
        t for t in tasks
        if t.get("due_date")
        and day_start <= _make_aware(t["due_date"]) < day_end
    ]
    completion_rate = (
        len(completed_today) / len(total_due_today)
        if total_due_today else 0.0
    )

    record = {
        "user_id": user_id,
        "date": today,
        "tasks_completed": len(completed_today),
        "tasks_created": len(created_today),
        "focus_hours": round(focus_hours, 2),
        "completion_rate": round(completion_rate, 2),
        "avg_completion_time_hours": round(avg_completion_time, 2),
        "recorded_at": datetime.now(timezone.utc),
    }

    # Upsert — one doc per user per day
    await db["analytics"].update_one(
        {"user_id": user_id, "date": today},
        {"$set": record},
        upsert=True,
    )


# ── Get analytics summary ─────────────────────────────────────────

async def get_analytics_summary(user_id: str) -> AnalyticsSummary:
    db = get_database()
    now = datetime.now(timezone.utc)

    tasks = await db["tasks"].find({"user_id": user_id}, {"_id": 0}).to_list(length=None)
    hours_per_task = _calc_hours_per_task(tasks)

    week_cutoff = now - timedelta(days=7)
    month_cutoff = now - timedelta(days=30)

    def _task_date(t: dict) -> datetime:
        return _make_aware(t["created_at"])

    week_tasks = [t for t in tasks if _task_date(t) >= week_cutoff]
    month_tasks = [t for t in tasks if _task_date(t) >= month_cutoff]

    week_completed = [t for t in week_tasks if t.get("status") == "completed"]
    month_completed = [t for t in month_tasks if t.get("status") == "completed"]

    weekly_rate = len(week_completed) / len(week_tasks) if week_tasks else 0.0
    monthly_rate = len(month_completed) / len(month_tasks) if month_tasks else 0.0

    # ── Weekly bar chart from analytics collection ────────────────
    week_start = (now - timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    week_dates = [
        (week_start + timedelta(days=i)).strftime("%Y-%m-%d")
        for i in range(7)
    ]
    analytics_records = await db["analytics"].find(
        {"user_id": user_id, "date": {"$in": week_dates}}
    ).to_list(length=7)
    record_map = {r["date"]: r for r in analytics_records}
    weekly_chart = [
        float(record_map.get(d, {}).get("tasks_completed", 0))
        for d in week_dates
    ]

    # ── Monthly line chart from analytics collection ───────────────
    year_start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    monthly_records = await db["analytics"].find(
        {"user_id": user_id, "date": {"$gte": year_start.strftime("%Y-%m-%d")}}
    ).to_list(length=366)
    monthly_chart: list[float] = [0.0] * 12
    for r in monthly_records:
        month_idx = int(r["date"].split("-")[1]) - 1
        monthly_chart[month_idx] += r.get("tasks_completed", 0)

    # ── Stat cards ────────────────────────────────────────────────
    n_week_done = len(week_completed)
    # Use actual focus hours from analytics collection if available
    week_focus = sum(
    min(record_map.get(d, {}).get("focus_hours", 0.0), 24.0) for d in week_dates
)
    def _format_hours(h: float) -> str:
        if h == 0:
            return "0h"
        if h < 0.1:
            return f"{int(h * 60)}m"
        if h < 1:
            return f"{h:.2f}h"
        return f"{h:.1f}h"

    focus_hours_str = _format_hours(week_focus if week_focus > 0 else n_week_done * hours_per_task)
    avg_time = _format_hours(hours_per_task) if n_week_done > 0 else "–"

    n_month_done = len(month_completed)
    n_month_total = len(month_tasks)
    efficiency_pct = round(n_month_done / n_month_total * 100) if n_month_total > 0 else 0

    all_completed = [t for t in tasks if t.get("status") == "completed"]
    total_completed = len(all_completed)
    total_tasks = len(tasks)

    # ── Achievements (FIXED INDENTATION) ──────────────────────────────
    # ── Achievements & Insights ───────────────────────────────────────
    achievements: list[AchievementItem] = []

    # 1. Completion streak — how many consecutive days with completed tasks
    streak = 0
    check_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
    for _ in range(30):  # check up to 30 days back
        date_str = check_date.strftime("%Y-%m-%d")
        record = record_map.get(date_str) or next(
            (r for r in analytics_records if r.get("date") == date_str), None
        )
        if record and record.get("tasks_completed", 0) > 0:
            streak += 1
            check_date -= timedelta(days=1)
        else:
            break

    if streak >= 2:
        achievements.append(AchievementItem(
            icon="🔥",
            title=f"{streak}-day completion streak!",
            subtitle="Keep the momentum going.",
        ))

    # 2. Weekly goal performance
    if len(week_tasks) >= 3:
        weekly_pct = int(weekly_rate * 100)
        if weekly_pct >= 70:
            achievements.append(AchievementItem(
                icon="🎯",
                title=f"Met {weekly_pct}% of weekly goals",
                subtitle="Excellent execution this week!",
            ))

    # 3. Overdue reduction insight
    total_pending = len([t for t in tasks if t.get("status") != "completed"])
    if total_completed > 0 and total_pending > 0:
        completion_ratio = int((total_completed / total_tasks) * 100)
        if completion_ratio >= 30:
            achievements.append(AchievementItem(
                icon="⭐",
                title=f"Task backlog reduced by {completion_ratio}%",
                subtitle="You're closing gaps before deadlines stack up.",
            ))

    # 4. Today's momentum
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    completed_today_count = len([
        t for t in tasks
        if t.get("status") == "completed"
        and t.get("completed_at")
        and _make_aware(t["completed_at"]) >= day_start
    ])
    if completed_today_count >= 2:
        achievements.append(AchievementItem(
            icon="💪",
            title=f"{completed_today_count} tasks crushed today!",
            subtitle="Strong daily performance. Keep it up!",
        ))

    # 5. Power user milestone
    if total_completed >= 10:
        achievements.append(AchievementItem(
            icon="🏆",
            title=f"{total_completed} tasks completed!",
            subtitle="You're a Cognify power user.",
        ))

    # 6. Clean slate — no overdue
    overdue_count = len([
        t for t in tasks
        if t.get("status") != "completed"
        and t.get("due_date")
        and _make_aware(t["due_date"]) < now
    ])
    if total_tasks > 0 and overdue_count == 0:
        achievements.append(AchievementItem(
            icon="✅",
            title="No overdue tasks!",
            subtitle="Everything is on track. Well done!",
        ))

    # Fallback — always show something useful
    if not achievements:
        if total_completed == 0:
            achievements.append(AchievementItem(
                icon="🚀",
                title="Ready to launch!",
                subtitle="Complete your first task to start earning insights.",
            ))
        else:
            achievements.append(AchievementItem(
                icon="📈",
                title=f"{total_completed} task{'s' if total_completed > 1 else ''} completed so far",
                subtitle="Keep completing tasks to unlock more insights.",
            ))

    return AnalyticsSummary(
        weekly_completion_rate=weekly_rate,
        monthly_completion_rate=monthly_rate,
        weekly_chart_data=weekly_chart,
        monthly_chart_data=monthly_chart,
        weekly_stats=WeeklyStats(focus_hours=focus_hours_str, avg_time=avg_time),
        monthly_stats=MonthlyStats(
            tasks_completed=str(n_month_done),
            efficiency=f"{efficiency_pct}%",
        ),
        achievements=achievements,
        total_completed=total_completed,
        total_tasks=total_tasks,
    )