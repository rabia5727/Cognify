from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone


# --------------------------
# Milestone structure (part of a workflow)
# --------------------------
class Milestone(BaseModel):
    id: str                                    # unique milestone ID
    title: str                                 # milestone name
    due_date: Optional[datetime] = None        # when should it be done?
    completed: bool = False                    # is it done?
    completed_at: Optional[datetime] = None    # when was it completed?


# --------------------------
# What we store in the database
# --------------------------
class WorkflowInDB(BaseModel):
    title: str
    description: Optional[str] = None
    category: Optional[str] = None             # academic/freelance/personal
    user_id: str
    task_ids: List[str] = []                   # linked task IDs
    milestones: List[Milestone] = []           # list of milestones
    status: str = "active"                     # active/completed/archived
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# --------------------------
# What user sends when creating a workflow
# --------------------------
class WorkflowCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = None


# --------------------------
# What user sends when creating a milestone
# --------------------------
class MilestoneCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    due_date: Optional[datetime] = None


# --------------------------
# What user sends when updating a workflow
# --------------------------
class WorkflowUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = None
    status: Optional[str] = None              # active/completed/archived


# --------------------------
# What we send back to the user
# --------------------------
class WorkflowResponse(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    user_id: str
    task_ids: List[str] = []
    milestones: List[Milestone] = []
    status: str
    progress: float = 0.0                     # percentage of milestones completed
    created_at: datetime
    updated_at: datetime