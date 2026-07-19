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
    notifications_enabled: bool = True    
    notification_permission_asked: bool = False   
    theme: str = "light"        # light or dark mode
    voice_permission: bool = False             


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
    notification_permission_asked: Optional[bool] = None 
    theme: Optional[str] = None
    voice_permission: Optional[bool] = None  #



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