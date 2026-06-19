from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime, timezone

# ── Valid value sets ───────────────────────────────────────────────
VALID_STATUSES = {"pending", "in_progress", "completed"}
VALID_PRIORITIES = {"low", "medium", "high"}
VALID_CATEGORIES = {"academic", "freelance", "general", "email", "classroom"}

# ── Shared validator helpers ───────────────────────────────────────

def _validate_priority(v):
    if v and v not in VALID_PRIORITIES:
        raise ValueError(f"Priority must be one of: {VALID_PRIORITIES}")
    return v

def _validate_category(v):
    if v and v not in VALID_CATEGORIES:
        raise ValueError(f"Category must be one of: {VALID_CATEGORIES}")
    return v

def _validate_due_date_create(v):
    """
    Only used on CREATE — prevents creating new tasks with past dates.
    NOT used on UPDATE — overdue tasks must still be updatable.
    """
    if v:
        now = datetime.now(timezone.utc)
        if v.tzinfo is None:
            v = v.replace(tzinfo=timezone.utc)
        if v.date() < now.date():
            raise ValueError("Due date cannot be in the past")
    return v

def _normalize_due_date(v):
    """
    Used on UPDATE — only normalizes timezone, never rejects past dates.
    This is critical: overdue tasks have past due_dates and must still
    be completable (checkbox toggle sends the existing due_date back).
    """
    if v and v.tzinfo is None:
        v = v.replace(tzinfo=timezone.utc)
    return v


# ── TaskSchema (internal / DB representation) ──────────────────────
class TaskSchema(BaseModel):
    title: str
    description: Optional[str] = None
    status: str = "pending"
    priority: str = "medium"
    category: Optional[str] = None
    due_date: Optional[datetime] = None
    due_time: Optional[str] = None
    project_id: Optional[str] = None

    source: Optional[str] = None
    source_id: Optional[str] = None
    course_id: Optional[str] = None

    user_id: str

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )


# ── TaskCreate (what Flutter sends when creating a task) ───────────
class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    priority: Optional[str] = "medium"
    category: Optional[str] = None
    due_date: Optional[datetime] = None
    due_time: Optional[str] = None
    project_id: Optional[str] = None

    source: Optional[str] = None
    source_id: Optional[str] = None
    course_id: Optional[str] = None

    @field_validator("priority")
    def validate_priority(cls, v):
        return _validate_priority(v)

    @field_validator("category")
    def validate_category(cls, v):
        return _validate_category(v)

    @field_validator("due_date")
    def validate_due_date(cls, v):
        # ✅ CREATE: reject past dates (user shouldn't create tasks already overdue)
        return _validate_due_date_create(v)


# ── TaskUpdate (what Flutter sends when editing / toggling a task) ──
class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[str] = None
    due_date: Optional[datetime] = None   # ✅ NO past-date rejection here
    due_time: Optional[str] = None
    project_id: Optional[str] = None

    @field_validator("status")
    def validate_status(cls, v):
        if v and v not in VALID_STATUSES:
            raise ValueError(f"Status must be one of: {VALID_STATUSES}")
        return v

    @field_validator("priority")
    def validate_priority(cls, v):
        return _validate_priority(v)

    @field_validator("category")
    def validate_category(cls, v):
        return _validate_category(v)

    @field_validator("due_date")
    def normalize_due_date(cls, v):
        # ✅ UPDATE: only normalize timezone, NEVER reject past dates.
        # Overdue tasks have past due_dates — completing them sends
        # the original due_date back. Rejecting it would break all
        # checkbox toggles for overdue tasks.
        return _normalize_due_date(v)


# ── TaskResponse (what the API sends back to Flutter) ──────────────
class TaskResponse(BaseModel):
    id: str
    user_id: str
    title: str
    description: Optional[str]
    status: str
    priority: str
    category: Optional[str] = None
    due_date: Optional[datetime]
    due_time: Optional[str] = None
    project_id: Optional[str] = None

    source: Optional[str] = None
    source_id: Optional[str] = None
    course_id: Optional[str] = None

    created_at: datetime
    updated_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None