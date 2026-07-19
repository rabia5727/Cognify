# app/routes/emails.py
# Email routes
#
# Register in main.py:
#   from app.routes.emails import router as emails_router
#   app.include_router(emails_router)
#
# RABIA implements POST /emails/send
# Taiba's email agent stores the draft in pending_action.
# When user confirms, _execute_pending_action calls send_email_via_gmail().
# This route is Rabia's alternative entry point if needed from Flutter directly.

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.utils.dependencies import get_current_user



router = APIRouter(prefix="/emails", tags=["emails"])


class EmailSendRequest(BaseModel):
    """
    Structured email ready to send.
    Matches the pending_action["type"] == "send_email" format exactly.
    """
    to:      str
    subject: str
    body:    str


class EmailSendResponse(BaseModel):
    success: bool
    message: str


@router.post("/send", response_model=EmailSendResponse)
async def send_email(
    request: EmailSendRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Sends an email via Gmail API.

    ┌──────────────────────────────────────────┐
    │  RABIA implements this endpoint          │
    │                                          │
    │  She calls send_email_via_gmail() from   │
    │  app/crud/email_generator.py with:       │
    │    to      = request.to                  │
    │    subject = request.subject             │
    │    body    = request.body                │
    │    user_id = str(current_user["_id"])    │
    └──────────────────────────────────────────┘
    """
    try:
        user_id = str(current_user["_id"])

        # Rabia replaces this with her actual implementation
        from app.crud.email_generator import send_email_via_gmail
        result = await send_email_via_gmail(
            to=request.to,
            subject=request.subject,
            body=request.body,
            user_id=user_id,
        )
        return EmailSendResponse(success=True, message=result)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))