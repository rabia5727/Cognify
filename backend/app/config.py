from pydantic_settings import BaseSettings
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    # MongoDB
    MONGO_URI: str
    DB_NAME: str = "cognify"
    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080 
    # Google OAuth - Classroom
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    # Google OAuth - Gmail
    GMAIL_CLIENT_ID: str = ""
    GMAIL_CLIENT_SECRET: str = ""
    # URLs
    API_URL: str = "http://127.0.0.1:8000"
    FRONTEND_URL: str = "http://localhost:3000"
    MOBILE_REDIRECT_URI: str = "http://localhost:8000/classroom/mobile_oauth_callback"
    GROQ_API_KEY: str = ""
    # Google OAuth - Drive
    GOOGLE_DRIVE_CLIENT_ID: str = ""
    GOOGLE_DRIVE_CLIENT_SECRET: str = ""
    # Connect All
    CONNECT_ALL_CLIENT_ID: str = ""
    CONNECT_ALL_CLIENT_SECRET: str = ""

    class Config:
        env_file = str(BASE_DIR / ".env")
        extra = "ignore"  

settings = Settings()