from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

client: AsyncIOMotorClient = None

def get_database():
    return client[settings.DB_NAME]

async def connect_db():
    global client
    client = AsyncIOMotorClient(settings.MONGO_URI)
    print("Connected to MongoDB Atlas")

async def close_db():
    global client
    if client:
        client.close()
        print("MongoDB connection closed")