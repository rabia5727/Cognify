from fastapi import APIRouter, HTTPException, status, Depends, Query
from pydantic import BaseModel
from app.models.notification import NotificationCreate, NotificationResponse
from app.crud.notification import (
    create_notification,
    get_notifications,
    get_unread_count,
    mark_as_read,
    mark_all_read,
    delete_notification,
    delete_multiple,
    mark_multiple_as_read,
    get_upcoming_reminders,
    snooze_reminder,
)
from app.crud.notifications_triggers import check_due_tasks
from app.utils.dependencies import get_current_user


class BatchIdsRequest(BaseModel):
    ids: list[str]

class SnoozeRequest(BaseModel):
    minutes: int = 10

router = APIRouter(prefix="/notifications", tags=["Notifications"])


# ── Static routes FIRST (specific) ───────────────────────────────────────────

# POST /notifications/
@router.post("/", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
async def create_new_notification(
    data: NotificationCreate,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    return await create_notification(data, user_id)


# GET /notifications/
# routes/notification.py — GET / route, confirm it looks like this:
@router.get("/")
async def get_all_notifications(
    unread_only: bool = Query(False),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    skip = (page - 1) * page_size
    # This already returns the dict with pagination — just return it directly
    return await get_notifications(
        user_id,
        unread_only=unread_only,
        skip=skip,
        limit=page_size
    )



# GET /notifications/unread-count
@router.get("/unread-count")
async def unread_count(current_user: dict = Depends(get_current_user)):
    user_id = str(current_user["_id"])
    count = await get_unread_count(user_id)
    return {"unread_count": count}


# POST /notifications/refresh
@router.post("/refresh")
async def refresh_proactive(current_user: dict = Depends(get_current_user)):
    user_id = str(current_user["_id"])
    created = await check_due_tasks(user_id)
    return {"new_notifications": created}


# PATCH /notifications/read-all       ← BEFORE /{id} routes
@router.patch("/read-all")
async def read_all(current_user: dict = Depends(get_current_user)):
    user_id = str(current_user["_id"])
    modified = await mark_all_read(user_id)
    return {"marked_read": modified}


# PATCH /notifications/batch/read     ← BEFORE /{id} routes
@router.patch("/batch/read")
async def batch_mark_read(
    body: BatchIdsRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    modified = await mark_multiple_as_read(body.ids, user_id)
    return {"marked_read": modified}


# DELETE /notifications/batch/        ← BEFORE /{id} routes
@router.delete("/batch/", status_code=status.HTTP_204_NO_CONTENT)
async def batch_delete(
    body: BatchIdsRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    await delete_multiple(body.ids, user_id)


# GET /notifications/reminders/upcoming  ← BEFORE /{id} routes

@router.get("/reminders/upcoming")  
async def upcoming_reminders(
    hours_ahead: int = Query(24, ge=1, le=168),
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    reminders = await get_upcoming_reminders(user_id, hours_ahead=hours_ahead)
    return {"reminders": reminders}


# ── Dynamic routes LAST ───────────────────────────────────────────────────────

# PATCH /notifications/{id}/read
@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def read_one(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    notification = await mark_as_read(notification_id, user_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


# PATCH /notifications/{id}/snooze
@router.patch("/{notification_id}/snooze", response_model=NotificationResponse)
async def snooze(
    notification_id: str,
    body: SnoozeRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    notification = await snooze_reminder(notification_id, user_id, body.minutes)
    if not notification:
        raise HTTPException(status_code=404, detail="Reminder not found")
    return notification


# DELETE /notifications/{id}
@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_one(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    deleted = await delete_notification(notification_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Notification not found")