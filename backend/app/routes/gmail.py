# Purpose: Gmail API endpoints
# Endpoints:
#   GET /gmail/oauth/mobile-auth - Generate OAuth URL
#   GET /gmail/oauth/mobile-callback - Handle OAuth callback
#   POST /gmail/sync - Fetch, classify, and create tasks from emails
#   GET /gmail/emails - Get stored emails
#   POST /gmail/emails/{id}/task - Manually create task from email
#   POST /gmail/emails/{id}/archive - Archive email
#   GET /gmail/health - Check connection status
#   POST /gmail/disconnect - Remove Gmail tokens

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
from bson import ObjectId
from google_auth_oauthlib.flow import Flow

from app.db.connection import get_database
from app.utils.dependencies import get_current_user
from app.services.gmail_service import GmailService
from app.crud.task import create_task
from app.models.task import TaskCreate
from app.config import settings

router = APIRouter(prefix="/gmail", tags=["Gmail"])

# OAuth scopes
SCOPES = [
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
]

MOBILE_REDIRECT_URI = f"{settings.API_URL}/gmail/oauth/mobile-callback"


def _gmail_client_id() -> str:
    return settings.GMAIL_CLIENT_ID or settings.GOOGLE_CLIENT_ID


def _gmail_client_secret() -> str:
    return settings.GMAIL_CLIENT_SECRET or settings.GOOGLE_CLIENT_SECRET


def get_flow():
    """Create OAuth flow instance for Gmail"""
    return Flow.from_client_config(
        {
            "web": {
                "client_id": _gmail_client_id(),
                "client_secret": _gmail_client_secret(),
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [MOBILE_REDIRECT_URI]
            }
        },
        scopes=SCOPES,
        redirect_uri=MOBILE_REDIRECT_URI
    )


class CreateTaskRequest(BaseModel):
    title: str
    description: Optional[str] = None
    priority: str = "medium"
    category: str = "email"
    due_date: Optional[datetime] = None


# ─────────────────────────────────────────────────────────────────
# OAUTH ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/oauth/mobile-auth")
async def mobile_oauth_auth(current_user: dict = Depends(get_current_user)):
    """Generate OAuth URL for Gmail connection"""
    flow = get_flow()
    state = str(ObjectId())
    
    db = get_database()
    await db.oauth_states.insert_one({
        "state": state,
        "user_id": str(current_user["_id"]),
        "type": "gmail",
        "created_at": datetime.utcnow()
    })
    
    auth_url, _ = flow.authorization_url(
        access_type='offline',
        include_granted_scopes='true',
        prompt='consent',
        state=state
    )
    
    return {"auth_url": auth_url, "state": state}


@router.get("/oauth/mobile-callback")
async def mobile_oauth_callback(code: str, state: str):
    """Handle Gmail OAuth callback"""
    db = get_database()
    
    try:
        stored_state = await db.oauth_states.find_one({"state": state})
        if not stored_state:
            return HTMLResponse("Invalid state", status_code=400)
        
        user_id = stored_state["user_id"]
        await db.oauth_states.delete_one({"state": state})
        
        flow = get_flow()
        flow.fetch_token(code=code)
        credentials = flow.credentials
        
        # Store tokens
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "gmail_tokens": {
                    "access_token": credentials.token,
                    "refresh_token": credentials.refresh_token,
                    "connected_at": datetime.utcnow()
                }
            }}
        )
        
        return HTMLResponse("""
            <html>
            <body style="font-family:sans-serif; text-align:center; padding:40px; background:#f0f4FF;">
                <h2 style="color:#1360E2;">✅ Gmail Connected!</h2>
                <p>You have successfully connected to Gmail.</p>
                <p style="color:#64748B;">You can now return to the app.</p>
            </body>
            </html>
        """)
        
    except Exception as e:
        return HTMLResponse(f"Connection failed: {str(e)}", status_code=400)


# ─────────────────────────────────────────────────────────────────
# EMAIL ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/health")
async def gmail_health(current_user: dict = Depends(get_current_user)):
    """Check Gmail connection status"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'gmail_tokens' in user if user else False
    
    return {
        "connected": has_tokens,
        "message": "Gmail integration ready" if has_tokens else "Not connected to Gmail"
    }


@router.post("/disconnect")
async def disconnect_gmail(current_user: dict = Depends(get_current_user)):
    """Disconnect Gmail account"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])
    
    await db.users.update_one(
        {"_id": user_id},
        {"$unset": {"gmail_tokens": "", "gmail_emails": ""}}
    )
    
    return {"message": "Gmail disconnected successfully"}


@router.post("/sync")
async def sync_emails(
    max_results: int = 50,
    current_user: dict = Depends(get_current_user)
):
    """Fetch and sync emails from Gmail"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    # Check if connected
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'gmail_tokens' in user if user else False
    
    if not has_tokens:
        raise HTTPException(status_code=400, detail="Gmail not connected")
    
    result = await GmailService.sync_emails(user_id, db, max_results)
    
    return {
        "message": f"Synced {result['synced']} emails, created {result['tasks_created']} tasks",
        **result
    }


@router.get("/emails")
async def get_emails(
    limit: int = 50,
    current_user: dict = Depends(get_current_user)
):
    """Get stored emails from database"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    emails = await GmailService.get_stored_emails(user_id, db, limit)
    
    # Convert ObjectId to string for JSON
    for email in emails:
        email['_id'] = str(email['_id'])
        email['user_id'] = str(email['user_id'])
    
    return {"emails": emails, "count": len(emails)}


@router.post("/emails/{email_id}/task")
async def create_task_from_email(
    email_id: str,
    request: CreateTaskRequest,
    current_user: dict = Depends(get_current_user)
):
    """Manually create a Cognify task from an email"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    # Get email
    email = await db.gmail_emails.find_one({
        "user_id": ObjectId(user_id),
        "email_id": email_id
    })
    
    if not email:
        raise HTTPException(status_code=404, detail="Email not found")
    
    # Create task
    task_data = TaskCreate(
        title=request.title,
        description=request.description or f"From email: {email.get('subject', '')}",
        priority=request.priority,
        category=request.category,
        source="gmail",
        source_id=email_id,
        email_sender=email.get('sender'),
        email_subject=email.get('subject'),
        email_snippet=email.get('snippet'),
        email_thread_id=email.get('thread_id'),
        due_date=request.due_date,
    )
    
    created_task = await create_task(task_data, user_id)
    
    # Update email
    await db.gmail_emails.update_one(
        {"_id": email['_id']},
        {"$set": {
            "is_task_created": True,
            "task_id": str(created_task.id),
            "updated_at": datetime.utcnow()
        }}
    )
    
    return {
        "message": "Task created successfully",
        "task_id": str(created_task.id)
    }


@router.post("/emails/{email_id}/archive")
async def archive_email(
    email_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Archive email in Gmail"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    success = await GmailService.archive_email(user_id, db, email_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to archive email")
    
    return {"message": "Email archived"}


@router.post("/emails/{email_id}/read")
async def mark_email_read(
    email_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Mark email as read in Gmail"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    success = await GmailService.mark_as_read(user_id, db, email_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to mark email as read")
    
    return {"message": "Email marked as read"}