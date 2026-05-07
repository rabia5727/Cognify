from pydantic import BaseModel, Field
from typing import List
from datetime import datetime,timezone


class AchievementItem(BaseModel):
    icon: str
    title: str
    subtitle: str


class WeeklyStats(BaseModel):
    focus_hours: str
    avg_time: str


class MonthlyStats(BaseModel):
    tasks_completed: str
    efficiency: str


class AnalyticsSummary(BaseModel):
    weekly_completion_rate: float
    monthly_completion_rate: float
    weekly_chart_data: List[float]
    monthly_chart_data: List[float]
    weekly_stats: WeeklyStats
    monthly_stats: MonthlyStats
    achievements: List[AchievementItem]
    total_completed: int
    total_tasks: int

class AnalyticsDailyRecord(BaseModel):
    user_id: str
    date: str                          # "YYYY-MM-DD"
    tasks_completed: int = 0
    tasks_created: int = 0
    focus_hours: float = 0.0           # sum of actual time per completed task
    completion_rate: float = 0.0       # completed / total for that day
    avg_completion_time_hours: float = 0.0  # avg hours per completed task
    recorded_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))