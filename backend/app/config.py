from pydantic_settings import BaseSettings
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    MONGO_URI: str
    DB_NAME: str = "cognify"
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080 
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    API_URL: str = "http://127.0.0.1:8000"
    FRONTEND_URL: str = "http://localhost:3000"
    MOBILE_REDIRECT_URI: str = "http://localhost:8000/classroom/mobile_oauth_callback"

    class Config:
        env_file = str(BASE_DIR / ".env")

settings = Settings()