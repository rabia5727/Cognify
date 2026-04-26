from pydantic import BaseModel
from typing import List


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
