# Purpose: storage for password-reset OTP codes.
# One pending code per email — a new request overwrites any existing one.
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.db.connection import get_database

OTP_TTL_MINUTES = 10
MAX_ATTEMPTS = 5


async def setup_indexes() -> None:
    db = get_database()
    col = db["password_resets"]
    await col.create_index("email", unique=True)
    # TTL index: Mongo auto-deletes the document once expires_at is past,
    # so stale/unused codes clean themselves up with no cron job needed.
    await col.create_index("expires_at", expireAfterSeconds=0)


async def create_or_replace_otp(email: str, otp_hash: str) -> None:
    db = get_database()
    now = datetime.now(timezone.utc)
    await db["password_resets"].replace_one(
        {"email": email},
        {
            "email": email,
            "otp_hash": otp_hash,
            "attempts": 0,
            "created_at": now,
            "expires_at": now + timedelta(minutes=OTP_TTL_MINUTES),
        },
        upsert=True,
    )


async def get_otp(email: str) -> Optional[dict]:
    db = get_database()
    doc = await db["password_resets"].find_one({"email": email})
    if not doc:
        return None
    expires_at = doc["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        return None  # expired but not yet TTL-swept — treat as gone
    return doc


async def increment_attempts(email: str) -> None:
    db = get_database()
    await db["password_resets"].update_one(
        {"email": email}, {"$inc": {"attempts": 1}}
    )


async def delete_otp(email: str) -> None:
    db = get_database()
    await db["password_resets"].delete_one({"email": email})
