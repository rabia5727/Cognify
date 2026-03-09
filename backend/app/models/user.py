from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# --------------------------
# User preferences structure
# --------------------------
class UserPreferences(BaseModel):
    notifications_enabled: bool = True        # receive reminders?
    daily_work_hours: int = 8                 # how many hours per day?
    categories: list[str] = ["academic", "freelance", "personal"]  # active categories
    theme: str = "light"                      # light or dark mode


# --------------------------
# What we store in the database
# --------------------------
class UserInDB(BaseModel):
    name: str
    email: EmailStr
    password_hash: Optional[str] = None       # None for Google login users
    google_id: Optional[str] = None
    is_google_user: bool = False
    is_active: bool = True
    created_at: datetime = datetime.utcnow()
    preferences: UserPreferences = UserPreferences()  # default preferences


# --------------------------
# What user sends when registering
# --------------------------
class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str


# --------------------------
# What user sends when logging in
# --------------------------
class UserLogin(BaseModel):
    email: EmailStr
    password: str


# --------------------------
# What user sends when updating profile
# --------------------------
class UserUpdate(BaseModel):
    name: Optional[str] = None
    preferences: Optional[UserPreferences] = None


# --------------------------
# What we send back to user (never expose password_hash)
# --------------------------
class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    is_google_user: bool
    created_at: datetime
    preferences: UserPreferences