from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal
from datetime import datetime, timezone

# Allowed values for validation
VALID_STATUSES = {"pending", "in_progress", "completed"}
VALID_PRIORITIES = {"low", "medium", "high"}


# --------------------------
# What we store in the database
# --------------------------
class TaskSchema(BaseModel):
    title: str
    description: Optional[str] = None
    status: str = "pending"
    priority: str = "medium"
    category: Optional[Literal["academic", "freelance", "personal"]] = None  # NEW
    due_date: Optional[datetime] = None
    user_id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# --------------------------
# What user sends when creating a task
# --------------------------
class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    priority: Optional[str] = "medium"
    category: Optional[Literal["academic", "freelance", "personal"]] = None  # NEW
    due_date: Optional[datetime] = None

    @field_validator("priority")
    def validate_priority(cls, v):
        if v not in VALID_PRIORITIES:
            raise ValueError(f"Priority must be one of: {VALID_PRIORITIES}")
        return v

    @field_validator("due_date")
    def validate_due_date(cls, v):
        if v:
            # Get current time with timezone
            now = datetime.now(timezone.utc)
            # If due_date has no timezone, add UTC to it
            if v.tzinfo is None:
                v = v.replace(tzinfo=timezone.utc)
            # Compare ONLY the date part (ignore time)
            if v.date() < now.date():
                raise ValueError("Due date cannot be in the past")
        return v


# --------------------------
# What user sends when updating a task
# --------------------------
class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[Literal["academic", "freelance", "personal"]] = None  # NEW
    due_date: Optional[datetime] = None

    @field_validator("status")
    def validate_status(cls, v):
        if v and v not in VALID_STATUSES:
            raise ValueError(f"Status must be one of: {VALID_STATUSES}")
        return v

    @field_validator("priority")
    def validate_priority(cls, v):
        if v and v not in VALID_PRIORITIES:
            raise ValueError(f"Priority must be one of: {VALID_PRIORITIES}")
        return v

    @field_validator("due_date")
    def validate_due_date(cls, v):
        if v:
            # Get current time with timezone
            now = datetime.now(timezone.utc)
            # If due_date has no timezone, add UTC to it
            if v.tzinfo is None:
                v = v.replace(tzinfo=timezone.utc)
            # Compare ONLY the date part (ignore time)
            if v.date() < now.date():
                raise ValueError("Due date cannot be in the past")
        return v


# --------------------------
# What we send back to the user
# --------------------------
class TaskResponse(BaseModel):
    id: str
    user_id: str
    title: str
    description: Optional[str]
    status: str
    priority: str
    category: Optional[str] = None  # NEW
    due_date: Optional[datetime]
    created_at: datetime
    updated_at: Optional[datetime] = None