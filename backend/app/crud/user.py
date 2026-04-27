from app.db.connection import get_database
from app.models.user import UserInDB, UserUpdate
from bson import ObjectId
from bson.errors import InvalidId
from datetime import datetime, timezone


# Helper — safely converts string to ObjectId
# Returns None if the string is malformed (protects against HTTP 500)
def _to_object_id(user_id: str) -> ObjectId | None:
    try:
        return ObjectId(user_id)
    except (InvalidId, Exception):
        return None


# CREATE a new user
async def create_user(user_data: UserInDB) -> str:
    db = get_database()
    result = await db["users"].insert_one(user_data.model_dump())
    return str(result.inserted_id)


# GET user by email
async def get_user_by_email(email: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"email": email})
    return user


# GET user by ID
async def get_user_by_id(user_id: str) -> dict | None:
    oid = _to_object_id(user_id)
    if oid is None:
        return None  # malformed ID → return None → caller returns 401 not 500
    db = get_database()
    return await db["users"].find_one({"_id": oid})


# GET user by Google ID
async def get_user_by_google_id(google_id: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"google_id": google_id})
    return user


# UPDATE user profile
async def update_user(user_id: str, update_data: UserUpdate) -> dict | None:
    oid = _to_object_id(user_id)
    if oid is None:
        return None
    
    db = get_database()
    update_fields = {}

    if update_data.name is not None:
        update_fields["name"] = update_data.name

    if update_data.preferences is not None:
        update_fields["preferences"] = update_data.preferences.model_dump()

    # Nothing to update — return current user
    if not update_fields:
        return await get_user_by_id(user_id)

    update_fields["updated_at"] = datetime.now(timezone.utc)  # track updates

    await db["users"].update_one(
        {"_id": oid},
        {"$set": update_fields}
    )

    return await get_user_by_id(user_id)


# DELETE user account
async def delete_user(user_id: str) -> bool:
    oid = _to_object_id(user_id)
    if oid is None:
        return False
    
    db = get_database()
    result = await db["users"].delete_one({"_id": oid})
    return result.deleted_count == 1