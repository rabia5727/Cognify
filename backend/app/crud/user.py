from app.db.connection import get_database
from app.models.user import UserInDB
from bson import ObjectId

async def create_user(user_data: UserInDB) -> str:
    db = get_database()
    result = await db["users"].insert_one(user_data.model_dump())
    return str(result.inserted_id)

async def get_user_by_email(email: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"email": email})
    return user

async def get_user_by_id(user_id: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"_id": ObjectId(user_id)})
    return user

async def get_user_by_google_id(google_id: str) -> dict | None:
    db = get_database()
    user = await db["users"].find_one({"google_id": google_id})
    return user