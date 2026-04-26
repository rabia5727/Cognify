from fastapi import APIRouter, Depends
from app.models.analytics import AnalyticsSummary
from app.crud.analytics import get_analytics_summary
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/summary", response_model=AnalyticsSummary)
async def get_summary(current_user: dict = Depends(get_current_user)):
    """
    Return aggregated analytics for the authenticated user.

    ENDPOINT: GET /analytics/summary

    RETURNS:
        - weekly_completion_rate: float (0.0–1.0)
        - monthly_completion_rate: float (0.0–1.0)
        - weekly_chart_data: list[float] — tasks completed Mon–Sun (current week)
        - monthly_chart_data: list[float] — tasks completed Jan–Dec (current year)
        - weekly_stats: { focus_hours, avg_time }
        - monthly_stats: { tasks_completed, efficiency }
        - achievements: list of earned badges
        - total_completed: int
        - total_tasks: int
    """
    user_id = str(current_user["_id"])
    return await get_analytics_summary(user_id)
