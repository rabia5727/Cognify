# app/schedular.py
# APScheduler setup — background jobs that run automatically
#
# Jobs:
#   Job 1 (hourly)   — scan all users' tasks → create due_soon/overdue notifications
#   Job 2 (minutely) — trigger user-set reminders whose remind_at has passed
#   Job 3 (daily 8AM)— send proactive morning briefing to all users via CoCo
#
# Job 3 is Cognify's core research contribution:
# proactive assistance without user asking — differentiates from Siri/Alexa

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from app.crud.notifications_triggers import check_due_tasks
from app.crud.notification import process_due_reminders
from app.db.connection import get_database

scheduler = AsyncIOScheduler(timezone="UTC")


# ── Job 1: Runs every hour ────────────────────────────────────────
async def run_proactive_checks():
    """
    Every hour: scans all users' tasks.
    Creates due_soon (within 24h) and overdue notifications.
    Notifications appear in Flutter notification bell.
    """
    db = get_database()
    user_ids = await db["tasks"].distinct("user_id")

    total_created = 0
    for user_id in user_ids:
        created = await check_due_tasks(user_id)
        total_created += created

    if total_created > 0:
        print(f"✅ Proactive check done — {total_created} notifications created")


# ── Job 2: Runs every minute ──────────────────────────────────────
async def run_reminder_checks():
    """
    Every minute: finds reminders whose remind_at time has passed.
    Marks them triggered → Flutter polls and shows them.
    """
    count = await process_due_reminders()
    if count > 0:
        print(f"🔔 {count} reminder(s) triggered")


# ── Job 3: Runs daily at 8 AM UTC ────────────────────────────────
async def run_morning_briefings():
    """
    Every day at 8 AM UTC: sends personalized morning briefing to all users.
    CoCo reads their tasks, generates a briefing via Groq, saves it as:
      - a notification (shows in bell)
      - an assistant message (shows in CoCo chat)
    This is proactive assistance — user didn't ask for it.
    """
    # Import here to avoid circular imports at module load time
    from app.agents.proactive_agent import run_morning_briefings_for_all
    await run_morning_briefings_for_all()


# ── Start scheduler ───────────────────────────────────────────────
def start_notification_scheduler():
    # Job 1 — hourly task scan
    scheduler.add_job(
        run_proactive_checks,
        trigger="interval",
        hours=1,
        id="proactive_checks",
        replace_existing=True,
        misfire_grace_time=300,   # 5 min grace if server was busy
    )

    # Job 2 — minutely reminder trigger
    scheduler.add_job(
        run_reminder_checks,
        trigger="interval",
        minutes=1,
        id="reminder_checks",
        replace_existing=True,
        misfire_grace_time=60,
    )

    # Job 3 — daily 8 AM morning briefing
    # CronTrigger is more reliable than interval for daily jobs
    # because it won't drift if server restarts (always fires at exactly 8 AM)
    scheduler.add_job(
        run_morning_briefings,
        trigger=CronTrigger(hour=8, minute=0, timezone="UTC"),
        id="morning_briefings",
        replace_existing=True,
        misfire_grace_time=3600,  # 1 hour grace — if server was down at 8 AM,
                                  # fire within 1 hour of restart
    )

    scheduler.start()
    print("✅ Scheduler started — hourly checks, minutely reminders, daily 8AM briefings")


# ── Stop scheduler ────────────────────────────────────────────────
def stop_notification_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        print("🛑 Scheduler stopped")