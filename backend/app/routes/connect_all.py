from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from datetime import datetime
from bson import ObjectId
import requests
import urllib.parse

from app.db.connection import get_database
from app.utils.dependencies import get_current_user
from app.config import settings

router = APIRouter(prefix="/connect-all", tags=["Connect All"])

# ALL scopes combined
SCOPES = [
    # Classroom
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.me',
    'https://www.googleapis.com/auth/classroom.coursework.students',
    'https://www.googleapis.com/auth/classroom.rosters.readonly',
    # Gmail
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
    # Drive
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.readonly',
]

REDIRECT_URI = f"{settings.API_URL}/connect-all/oauth/callback"

def get_client_id():
    return settings.CONNECT_ALL_CLIENT_ID

def get_client_secret():
    return settings.CONNECT_ALL_CLIENT_SECRET


@router.get("/oauth/auth")
async def connect_all_auth(current_user: dict = Depends(get_current_user)):
    """Generate OAuth URL for all services combined"""
    state = str(ObjectId())
    
    db = get_database()
    await db.oauth_states.insert_one({
        "state": state,
        "user_id": str(current_user["_id"]),
        "service": "all",
        "created_at": datetime.utcnow()
    })
    
    # Build OAuth URL with ALL scopes
    params = {
        "client_id": get_client_id(),
        "redirect_uri": REDIRECT_URI,
        "scope": " ".join(SCOPES),
        "response_type": "code",
        "access_type": "offline",
        "include_granted_scopes": "true",
        "prompt": "consent",
        "state": state
    }
    
    auth_url = "https://accounts.google.com/o/oauth2/auth?" + urllib.parse.urlencode(params)
    
    return {"auth_url": auth_url, "state": state}


@router.get("/oauth/callback")
async def connect_all_callback(code: str, state: str):
    """Handle OAuth callback for all services"""
    db = get_database()
    
    try:
        stored_state = await db.oauth_states.find_one({"state": state})
        if not stored_state:
            return HTMLResponse("Invalid state", status_code=400)
        
        user_id = stored_state["user_id"]
        await db.oauth_states.delete_one({"state": state})
        
        # Exchange code for tokens
        token_url = "https://oauth2.googleapis.com/token"
        data = {
            "client_id": get_client_id(),
            "client_secret": get_client_secret(),
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "grant_type": "authorization_code"
        }
        
        response = requests.post(token_url, data=data)
        token_data = response.json()
        
        if "error" in token_data:
            return HTMLResponse(f"Token error: {token_data}", status_code=400)
        
        access_token = token_data.get("access_token")
        refresh_token = token_data.get("refresh_token")
        
        # ✅ Store tokens for ALL services
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "classroom_tokens": {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "connected_at": datetime.utcnow()
                },
                "gmail_tokens": {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "connected_at": datetime.utcnow()
                },
                "drive_tokens": {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "connected_at": datetime.utcnow()
                }
            }}
        )
        
        return HTMLResponse("""
            <html>
            <body style="font-family:sans-serif; text-align:center; padding:40px; background:#f0f4FF;">
                <h2 style="color:#1360E2;">✅ All Services Connected!</h2>
                <p>Google Classroom, Gmail, and Google Drive are now connected.</p>
                <p style="color:#64748B;">You can now return to the app.</p>
            </body>
            </html>
        """)
        
    except Exception as e:
        print(f"❌ Connect All Error: {e}")
        return HTMLResponse(f"Connection failed: {str(e)}", status_code=400)