from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import PyMongoError
import asyncio
from app.config import settings

client: AsyncIOMotorClient = None

def get_database():
    return client[settings.DB_NAME]

async def connect_db():
    global client
    last_error = None

    # Retry a few times so brief DNS/network glitches do not block local dev.
    for attempt in range(1, 4):
        try:
            client = AsyncIOMotorClient(
                settings.MONGO_URI,
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=5000,
            )
            await client.admin.command("ping")
            print("Connected to MongoDB Atlas")
            return
        except PyMongoError as exc:
            last_error = exc
            print(f"MongoDB connection attempt {attempt}/3 failed: {exc}")
            if client:
                client.close()
                client = None
            await asyncio.sleep(1)

    raise RuntimeError(f"Could not connect to MongoDB after 3 attempts: {last_error}")

async def close_db():
    global client
    if client:
        client.close()
        print("MongoDB connection closed")