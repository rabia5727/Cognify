from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.crud.notifications_triggers import check_due_tasks
from app.crud.notification import process_due_reminders
from app.db.connection import get_database

scheduler = AsyncIOScheduler(timezone="UTC")


# ── Job 1: Runs every hour — checks all users for due/overdue tasks ──────────
async def run_proactive_checks():
    """Every hour: scans tasks and creates due_soon/overdue notifications"""
    db = get_database()
    user_ids = await db["tasks"].distinct("user_id")

    total_created = 0
    for user_id in user_ids:
        created = await check_due_tasks(user_id)
        total_created += created

    print(f"✅ Proactive check done — {total_created} notifications created")


# ── Job 2: Runs every minute — triggers user-set reminders ───────────────────
async def run_reminder_checks():
    """Every minute: finds reminders whose remind_at time has passed"""
    count = await process_due_reminders()
    if count > 0:
        print(f"🔔 {count} reminder(s) triggered")


# ── Start scheduler ───────────────────────────────────────────────────────────
def start_notification_scheduler():
    # Hourly proactive task checks
    scheduler.add_job(
        run_proactive_checks,
        trigger="interval",
        hours=1,
        id="proactive_checks",
        replace_existing=True,
        misfire_grace_time=300,   # 5 min grace if server was busy
    )

    # Every minute reminder checks
    scheduler.add_job(
        run_reminder_checks,
        trigger="interval",
        minutes=1,
        id="reminder_checks",
        replace_existing=True,
        misfire_grace_time=60,    # 1 min grace
    )

    scheduler.start()
    print("✅ Notification scheduler started")


# ── Stop scheduler ────────────────────────────────────────────────────────────
def stop_notification_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        print("🛑 Notification scheduler stopped")