from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime


#------------------------------
# User Quiz Preferences
#------------------------------4
class QuizPreferences(BaseModel):
    goals: List[str] = []
    scheduleType: Optional[str] = None
    dailyTaskLoad: int = 5
    productivityChallenges: List[str] = []
    quizCompleted: bool = False

# --------------------------
# User preferences structure
# --------------------------
class UserPreferences(BaseModel):
    notifications_enabled: bool = True        # receive reminders?
    daily_work_hours: int = 8                 # how many hours per day?
    categories: list[str] = ["academic", "freelance", "general"]  # active categories
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
# Partial preferences update (only provided fields are changed)
# --------------------------
class UserPreferencesUpdate(BaseModel):
    notifications_enabled: Optional[bool] = None
    daily_work_hours: Optional[int] = None
    categories: Optional[list[str]] = None
    theme: Optional[str] = None


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