# This module defines the authentication routes for the FastAPI application,
# including user registration, login, Google login, and Google Classroom OAuth.
# Merged: rate limiting (main branch) + Classroom OAuth (google-classroom-integration branch)

from fastapi import APIRouter, HTTPException, status, Depends, Request
from pydantic import BaseModel
from app.models.user import UserRegister, UserLogin, UserResponse, UserInDB
from app.crud.user import create_user, get_user_by_email, get_user_by_google_id
from app.utils.auth import hash_password, verify_password, create_access_token, verify_google_token
from app.utils.dependencies import get_current_user
from app.db.connection import get_database
from app.limiter import limiter  # YOUR branch — rate limiting
import httpx                     # TEAMMATE's branch — needed for OAuth token exchange
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/auth", tags=["Authentication"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")


# ── Registration ───────────────────────────────────────────────────

@router.post("/register")
@limiter.limit("3/minute")
async def register(request: Request, user: UserRegister):
    # Check if email already exists
    existing = await get_user_by_email(user.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Create new user
    new_user = UserInDB(
        name=user.name,
        email=user.email,
        password_hash=hash_password(user.password)
    )
    user_id = await create_user(new_user)

    # Generate token
    token = create_access_token({"user_id": user_id})

    return {
        "message": "User registered successfully",
        "access_token": token,
        "token_type": "bearer"
    }


# ── Login ──────────────────────────────────────────────────────────

@router.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, user: UserLogin):
    # Find user
    db_user = await get_user_by_email(user.email)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    # Check password
    if not verify_password(user.password, db_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    # Generate token
    token = create_access_token({"user_id": str(db_user["_id"])})

    return {
        "message": "Login successful",
        "access_token": token,
        "token_type": "bearer"
    }


# ── Google Login (existing — Firebase/ID token flow) ───────────────

class GoogleTokenRequest(BaseModel):
    token: str

@router.post("/google")
async def google_login(request: GoogleTokenRequest):
    # Verify token with Google
    user_info = verify_google_token(request.token)
    if not user_info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token"
        )

    # Check if user already exists by google_id
    db_user = await get_user_by_google_id(user_info["google_id"])

    # If not, check by email
    if not db_user:
        db_user = await get_user_by_email(user_info["email"])

    # If still not found, create new user
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

    # Generate JWT token
    token = create_access_token({"user_id": user_id})

    return {
        "message": "Google login successful",
        "access_token": token,
        "token_type": "bearer"
    }


# ── Google Classroom OAuth (teammate's branch) ─────────────────────
# These endpoints handle the full OAuth2 code exchange flow,
# separate from the simple Google ID token login above.

class GoogleConnectRequest(BaseModel):
    code: str
    redirect_uri: str

@router.post("/google/connect")
async def connect_google(
    request: GoogleConnectRequest,
    current_user: dict = Depends(get_current_user)
):
    """Exchange authorization code for tokens and store in database."""
    db = get_database()

    # Exchange authorization code for access + refresh tokens
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tokens.get("error_description", "Failed to connect Google account")
        )

    # Get user info from Google to confirm identity
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {tokens['access_token']}"}
        )
        user_info = response.json()

    # Store tokens against the current user in MongoDB
    await db.users.update_one(
        {"_id": current_user["_id"]},
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
    """Check if the current user has a connected Google account."""
    db = get_database()
    user = await db.users.find_one({"_id": current_user["_id"]})

    has_tokens = bool(user and "classroom_tokens" in user)
    return {"connected": has_tokens}


@router.delete("/google/disconnect")
async def disconnect_google(current_user: dict = Depends(get_current_user)):
    """Remove stored Google tokens from the user's account."""
    db = get_database()

    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$unset": {"classroom_tokens": "", "google_user_info": ""}}
    )

    return {"message": "Google account disconnected"}