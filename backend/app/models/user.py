from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

# what we store in the database
class UserInDB(BaseModel):
    name: str
    email: EmailStr
    password_hash: Optional[str] = None  # None for Google login users
    google_id: Optional[str] = None
    is_google_user: bool = False
    is_active: bool = True
    created_at: datetime = datetime.utcnow()
    preferences: dict = {}

# what user sends when registering
class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str

# what user sends when logging in
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# what we send back to user (never expose password_hash)
class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    is_google_user: bool
    created_at: datetime