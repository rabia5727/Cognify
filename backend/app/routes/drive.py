from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
from bson import ObjectId
from google_auth_oauthlib.flow import Flow
import requests
import urllib.parse

from app.db.connection import get_database
from app.utils.dependencies import get_current_user
from app.services.google_drive_service import GoogleDriveService
from app.config import settings

router = APIRouter(prefix="/drive", tags=["Google Drive"])

# OAuth scopes for Drive
SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.readonly',
]

MOBILE_REDIRECT_URI = f"{settings.API_URL}/drive/oauth/mobile-callback"

# Get client credentials
def get_client_id():
    return settings.GOOGLE_DRIVE_CLIENT_ID or settings.GOOGLE_CLIENT_ID

def get_client_secret():
    return settings.GOOGLE_DRIVE_CLIENT_SECRET or settings.GOOGLE_CLIENT_SECRET


class UploadTextRequest(BaseModel):
    content: str
    file_name: str
    assignment_id: str
    course_id: str


@router.get("/oauth/mobile-auth")
async def mobile_oauth_auth(current_user: dict = Depends(get_current_user)):
    """Generate OAuth URL for Drive connection - NO PKCE"""
    state = str(ObjectId())
    
    db = get_database()
    await db.oauth_states.insert_one({
        "state": state,
        "user_id": str(current_user["_id"]),
        "service": "drive",
        "created_at": datetime.utcnow()
    })
    
    # ✅ Build OAuth URL manually - NO PKCE
    params = {
        "client_id": get_client_id(),
        "redirect_uri": MOBILE_REDIRECT_URI,
        "scope": " ".join(SCOPES),
        "response_type": "code",
        "access_type": "offline",
        "include_granted_scopes": "true",
        "prompt": "consent",
        "state": state
    }
    
    auth_url = "https://accounts.google.com/o/oauth2/auth?" + urllib.parse.urlencode(params)
    
    return {"auth_url": auth_url, "state": state}


@router.get("/oauth/mobile-callback")
async def mobile_oauth_callback(code: str, state: str):
    """Handle Drive OAuth callback"""
    db = get_database()
    
    try:
        stored_state = await db.oauth_states.find_one({"state": state})
        if not stored_state:
            return HTMLResponse("Invalid state", status_code=400)
        
        user_id = stored_state["user_id"]
        await db.oauth_states.delete_one({"state": state})
        
        # ✅ Exchange code for tokens using requests - NO PKCE
        token_url = "https://oauth2.googleapis.com/token"
        data = {
            "client_id": get_client_id(),
            "client_secret": get_client_secret(),
            "code": code,
            "redirect_uri": MOBILE_REDIRECT_URI,
            "grant_type": "authorization_code"
        }
        
        response = requests.post(token_url, data=data)
        token_data = response.json()
        
        if "error" in token_data:
            return HTMLResponse(f"Token error: {token_data}", status_code=400)
        
        # Store tokens
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "drive_tokens": {
                    "access_token": token_data.get("access_token"),
                    "refresh_token": token_data.get("refresh_token"),
                    "expires_at": datetime.utcnow() + timedelta(
                        seconds=token_data.get("expires_in", 3600)
                    ),
                    "connected_at": datetime.utcnow()
                }
            }}
        )
        
        return HTMLResponse("""
            <html>
            <body style="font-family:sans-serif; text-align:center; padding:40px; background:#f0f4FF;">
                <h2 style="color:#1360E2;">✅ Google Drive Connected!</h2>
                <p>You have successfully connected to Google Drive.</p>
                <p style="color:#64748B;">You can now upload files for assignments.</p>
            </body>
            </html>
        """)
        
    except Exception as e:
        print(f"❌ Drive OAuth Error: {e}")
        return HTMLResponse(f"Connection failed: {str(e)}", status_code=400)


@router.get("/health")
async def drive_health(current_user: dict = Depends(get_current_user)):
    """Check Drive connection status"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'drive_tokens' in user if user else False
    
    return {
        "connected": has_tokens,
        "message": "Drive integration ready" if has_tokens else "Not connected to Google Drive"
    }


@router.post("/disconnect")
async def disconnect_drive(current_user: dict = Depends(get_current_user)):
    """Disconnect Google Drive account"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    result = await GoogleDriveService.disconnect(user_id, db)
    return result


@router.post("/upload/text")
async def upload_text(
    request: UploadTextRequest,
    current_user: dict = Depends(get_current_user)
):
    """Upload text content to Google Drive"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    # Check if Drive is connected
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'drive_tokens' in user if user else False
    
    if not has_tokens:
        raise HTTPException(status_code=400, detail="Google Drive not connected")
    
    try:
        # Upload as PDF
        result = await GoogleDriveService.upload_text_as_pdf(
            user_id=user_id,
            db=db,
            content=request.content,
            file_name=request.file_name
        )
        
        # Store upload record
        await db.drive_uploads.insert_one({
            "user_id": ObjectId(user_id),
            "assignment_id": request.assignment_id,
            "course_id": request.course_id,
            "file_id": result['file_id'],
            "file_name": request.file_name,
            "share_link": result['share_link'],
            "created_at": datetime.utcnow()
        })
        
        return {
            "success": True,
            "file_id": result['file_id'],
            "share_link": result['share_link'],
            "message": "File uploaded successfully"
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))