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
    GROQ_API_KEY: str = ""
    ORCHESTRATOR_MODEL: str = "openai/gpt-oss-120b"
    LIGHTWEIGHT_MODEL: str = "openai/gpt-oss-20b"

    class Config:
        env_file = str(BASE_DIR / ".env")

settings = Settings()