#This module defines the authentication routes for the FastAPI application, including user registration, login, and Google authentication. It handles incoming requests, interacts with the user database, and generates JWT tokens for authenticated users. The routes include error handling for common issues such as duplicate email registration and invalid login credentials.
#registration, login, and google login endpoints 
from fastapi import APIRouter, HTTPException, status
from app.models.user import UserRegister, UserLogin, UserResponse
from app.crud.user import create_user, get_user_by_email
from app.utils.auth import hash_password, verify_password, create_access_token
from app.models.user import UserInDB
from pydantic import BaseModel
from app.limiter import limiter
from fastapi import Request

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register")
@limiter.limit("3/minute")
async def register(
    request: Request,
    user: UserRegister
    ):
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
@limiter.limit("5/minute")
async def login(
    request: Request, 
    user: UserLogin
    ):
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