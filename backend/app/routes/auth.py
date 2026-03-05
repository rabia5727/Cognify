from fastapi import APIRouter, HTTPException, status
from app.models.user import UserRegister, UserLogin, UserResponse
from app.crud.user import create_user, get_user_by_email
from app.utils.auth import hash_password, verify_password, create_access_token
from app.models.user import UserInDB

router = APIRouter(prefix="/auth", tags=["Authentication"])

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