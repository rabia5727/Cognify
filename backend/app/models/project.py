from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime

VALID_CATEGORIES = {"academic", "freelance", "personal"}
VALID_STATUSES = {"active", "completed"}
VALID_PRIORITIES = {"high", "medium", "low"}


class ProjectInDB(BaseModel):
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    user_id: str
    task_ids: List[str] = []
    status: str = "active"
    due_date: Optional[datetime] = None
    priority: str = "medium"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ProjectCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = None
    due_date: Optional[datetime] = None
    priority: Optional[str] = "medium"
    task_ids: List[str] = []

    @validator("category")
    def validate_category(cls, v):
        if v is not None and v not in VALID_CATEGORIES:
            raise ValueError(f"category must be one of {VALID_CATEGORIES}")
        return v

    @validator("priority")
    def validate_priority(cls, v):
        if v is not None and v not in VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {VALID_PRIORITIES}")
        return v


class ProjectUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = None
    status: Optional[str] = None
    due_date: Optional[datetime] = None
    priority: Optional[str] = None
    task_ids: Optional[List[str]] = None

    @validator("category")
    def validate_category(cls, v):
        if v is not None and v not in VALID_CATEGORIES:
            raise ValueError(f"category must be one of {VALID_CATEGORIES}")
        return v

    @validator("status")
    def validate_status(cls, v):
        if v is not None and v not in VALID_STATUSES:
            raise ValueError(f"status must be one of {VALID_STATUSES}")
        return v

    @validator("priority")
    def validate_priority(cls, v):
        if v is not None and v not in VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {VALID_PRIORITIES}")
        return v


class ProjectResponse(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    user_id: str
    task_ids: List[str] = []
    status: str
    due_date: Optional[datetime] = None
    priority: str
    progress: float = 0.0
    created_at: datetime
    updated_at: datetime
