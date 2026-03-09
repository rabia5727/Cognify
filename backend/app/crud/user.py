from app.db.connection import get_database
from app.models.user import UserInDB, UserUpdate
from bson import ObjectId
from datetime import datetime


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
    db = get_database()
    user = await db["users"].find_one({"_id": ObjectId(user_id)})
    return user


# GET user by Google ID
async def get_user_by_google_id(google_id: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"google_id": google_id})
    return user


# UPDATE user profile
async def update_user(user_id: str, update_data: UserUpdate) -> dict | None:
    db = get_database()

    # Build update dictionary with only provided fields
    update_fields = {}

    if update_data.name is not None:
        update_fields["name"] = update_data.name

    if update_data.preferences is not None:
        # model_dump() converts pydantic model to dictionary
        update_fields["preferences"] = update_data.preferences.model_dump()

    # If nothing to update, just return current user
    if not update_fields:
        return await get_user_by_id(user_id)

    # Perform the update in MongoDB
    await db["users"].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": update_fields}
    )

    # Return updated user
    return await get_user_by_id(user_id)


# DELETE user account
async def delete_user(user_id: str) -> bool:
    db = get_database()

    # Delete user document from MongoDB
    result = await db["users"].delete_one({"_id": ObjectId(user_id)})

    # deleted_count = 1 means success
    return result.deleted_count == 1