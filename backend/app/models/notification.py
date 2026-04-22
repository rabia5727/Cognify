from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal
from datetime import datetime, timezone


class NotificationInDB(BaseModel):
    id: str
    user_id: str
    title: str
    message: str
    type: str = "general"
    is_read: bool = False
    task_id: Optional[str] = None
    remind_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class NotificationCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    message: str = Field(..., min_length=1, max_length=500)
    type: Literal["reminder", "due_soon", "overdue", "achievement", "general"] = "general"
    task_id: Optional[str] = None
    remind_at: Optional[datetime] = None

    @field_validator("remind_at")
    def remind_at_must_be_future(cls, v):
        if v is None:
            return v
        now = datetime.now(timezone.utc)
        aware = v.replace(tzinfo=timezone.utc) if v.tzinfo is None else v
        if aware <= now:
            raise ValueError("remind_at must be a future datetime")
        return aware


class NotificationResponse(BaseModel):
    id: str
    user_id: str
    title: str
    message: str
    type: str
    is_read: bool
    task_id: Optional[str] = None
    remind_at: Optional[datetime] = None
    created_at: datetime
    is_triggered: bool = False                
    triggered_at: Optional[datetime] = None   
