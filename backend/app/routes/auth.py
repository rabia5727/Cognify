#This module defines the authentication routes for the FastAPI application, including user registration, login, and Google authentication. It handles incoming requests, interacts with the user database, and generates JWT tokens for authenticated users. The routes include error handling for common issues such as duplicate email registration and invalid login credentials.
#registration, login, and google login endpoints 
from fastapi import APIRouter, HTTPException, status, Depends
from app.models.user import UserRegister, UserLogin, UserResponse
from app.crud.user import create_user, get_user_by_email
from app.utils.auth import hash_password, verify_password, create_access_token
from app.models.user import UserInDB
from pydantic import BaseModel
from app.db.connection import get_database
from app.utils.dependencies import get_current_user
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/auth", tags=["Authentication"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")

@router.post("/register")
async def register(user: UserRegister):
    # check if email already exists
    existing = await get_user_by_email(user.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # create new user
    new_user = UserInDB(
        name=user.name,
        email=user.email,
        password_hash=hash_password(user.password)
    )
    user_id = await create_user(new_user)
    
    # generate token
    token = create_access_token({"user_id": user_id})
    
    return {
        "message": "User registered successfully",
        "access_token": token,
        "token_type": "bearer"
    }

@router.post("/login")
async def login(user: UserLogin):
    # find user
    db_user = await get_user_by_email(user.email)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # check password
    if not verify_password(user.password, db_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # generate token
    token = create_access_token({"user_id": str(db_user["_id"])})
    
    return {
        "message": "Login successful",
        "access_token": token,
        "token_type": "bearer"
    }

#google authentication and authorization
from app.utils.auth import verify_google_token
from app.crud.user import get_user_by_google_id

class GoogleTokenRequest(BaseModel):
    token: str

@router.post("/google")
async def google_login(request: GoogleTokenRequest):
    # verify token with google
    user_info = verify_google_token(request.token)
    if not user_info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token"
        )
    
    # check if user already exists by google_id
    db_user = await get_user_by_google_id(user_info["google_id"])
    
    # if not, check by email
    if not db_user:
        db_user = await get_user_by_email(user_info["email"])
    
    # if still not found, create new user
    if not db_user:
        new_user = UserInDB(
            name=user_info["name"],
            email=user_info["email"],
            google_id=user_info["google_id"],
            is_google_user=True
        )
        user_id = await create_user(new_user)
    else:
        user_id = str(db_user["_id"])
    
    # generate JWT token
    token = create_access_token({"user_id": user_id})
    
    return {
        "message": "Google login successful",
        "access_token": token,
        "token_type": "bearer"
    }

# =============================================================
# NEW GOOGLE CLASSROOM OAuth ENDPOINTS
# =============================================================

class GoogleConnectRequest(BaseModel):
    code: str
    redirect_uri: str

@router.post("/google/connect")
async def connect_google(
    request: GoogleConnectRequest,
    current_user: dict = Depends(get_current_user)
):
    """Exchange authorization code for tokens and store in database"""
    db = get_database()
    
    # Exchange code for tokens
    token_url = "https://oauth2.googleapis.com/token"
    data = {
        "code": request.code,
        "client_id": GOOGLE_CLIENT_ID,
        "client_secret": GOOGLE_CLIENT_SECRET,
        "redirect_uri": request.redirect_uri,
        "grant_type": "authorization_code"
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(token_url, data=data)
        tokens = response.json()
    
    if "error" in tokens:
        raise HTTPException(status_code=400, detail=tokens.get("error_description"))
    
    # Get user info from Google
    userinfo_url = "https://www.googleapis.com/oauth2/v2/userinfo"
    async with httpx.AsyncClient() as client:
        response = await client.get(
            userinfo_url,
            headers={"Authorization": f"Bearer {tokens['access_token']}"}
        )
        user_info = response.json()
    
    # Store tokens in database
    user_id = current_user["_id"]
    
    await db.users.update_one(
        {"_id": user_id},
        {"$set": {
            "classroom_tokens": {
                "access_token": tokens["access_token"],
                "refresh_token": tokens.get("refresh_token"),
                "expires_in": tokens.get("expires_in"),
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET
            },
            "google_user_info": user_info
        }}
    )
    
    return {
        "message": "Google account connected successfully",
        "user": user_info
    }

@router.get("/google/status")
async def google_status(current_user: dict = Depends(get_current_user)):
    """Check if user has connected Google account"""
    db = get_database()
    user = await db.users.find_one({"_id": current_user["_id"]})
    
    has_tokens = user and "classroom_tokens" in user
    return {"connected": has_tokens}

@router.delete("/google/disconnect")
async def disconnect_google(current_user: dict = Depends(get_current_user)):
    """Disconnect Google account"""
    db = get_database()
    
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$unset": {"classroom_tokens": "", "google_user_info": ""}}
    )
    
    return {"message": "Google account disconnected"}