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
    # Orchestrator and lightweight models.
    # llama-3.3-70b-versatile / llama-3.1-8b-instant are Groq's most mature,
    # heavily-optimized models — consistently sub-second in testing, vs.
    # openai/gpt-oss-120b/20b occasionally seeing 20-40s+ stalls under
    # Groq-side load (still fully supports tool-calling, verified).
    ORCHESTRATOR_MODEL: str = "openai/gpt-oss-120b"
    LIGHTWEIGHT_MODEL: str = "openai/gpt-oss-20b"
    # Backup models tried if the primary model's call fails or times out —
    # same Groq account, no extra signup, but a different model so a
    # problem specific to one model doesn't take the assistant down.
    ORCHESTRATOR_FALLBACK_MODEL: str = "qwen/qwen3.6-27b"
    LIGHTWEIGHT_FALLBACK_MODEL: str = "qwen/qwen3.6-27b"
    # Outbound mail (password reset OTP) — Gmail SMTP with an App Password,
    # not the GMAIL_CLIENT_ID/SECRET above (those are for per-user Gmail
    # OAuth in the assistant, a different thing from the app's own sender).
    SMTP_EMAIL: str = ""
    SMTP_APP_PASSWORD: str = ""

    class Config:
        env_file = str(BASE_DIR / ".env")
        extra = "ignore"  

settings = Settings()