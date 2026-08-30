# Purpose: remember tasks a user deleted that came from an external sync
# (Classroom, Gmail, ...), so the next auto-sync doesn't just re-import them.
# Without this, deleting a synced task is invisible to the sync loop — it
# just looks like an assignment that was never imported yet.
from datetime import datetime, timezone

from app.db.connection import get_database


async def setup_indexes() -> None:
    db = get_database()
    await db["sync_dismissals"].create_index(
        [("user_id", 1), ("source", 1), ("source_id", 1)], unique=True
    )


async def record_dismissal(user_id: str, source: str, source_id: str) -> None:
    db = get_database()
    await db["sync_dismissals"].update_one(
        {"user_id": user_id, "source": source, "source_id": source_id},
        {"$setOnInsert": {"dismissed_at": datetime.now(timezone.utc)}},
        upsert=True,
    )


async def get_dismissed_source_ids(user_id: str, source: str) -> set:
    db = get_database()
    cursor = db["sync_dismissals"].find(
        {"user_id": user_id, "source": source}, {"source_id": 1}
    )
    return {doc["source_id"] async for doc in cursor}
