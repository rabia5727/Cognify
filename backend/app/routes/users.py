from typing import List, Optional

from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from app.utils.dependencies import get_current_user
from app.utils.auth import verify_password, hash_password
from app.models.user import UserUpdate, UserResponse, UserPreferences, UserPreferencesUpdate
from app.crud.user import update_user, delete_user
from app.db.connection import get_database
from bson import ObjectId

router = APIRouter(prefix="/users", tags=["Users"])


# GET current user profile
@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    """
    ENDPOINT: GET /users/me
        - Returns the logged in user's profile
        - Requires JWT token
    """
    return {
        "id": str(current_user["_id"]),
        "name": current_user["name"],
        "email": current_user["email"],
        "is_google_user": current_user.get("is_google_user", False),
        "created_at": current_user["created_at"],
        # Return preferences or defaults if not set
        "preferences": current_user.get("preferences", UserPreferences().model_dump()),
        "quiz_preferences": current_user.get("quiz_preferences", None)    
    }


# UPDATE current user profile
@router.put("/me")
async def update_me(
    update_data: UserUpdate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: PUT /users/me
        - Update name and/or preferences
        - Requires JWT token
    """
    user_id = str(current_user["_id"])

    # Call CRUD function to update user
    updated_user = await update_user(user_id, update_data)

    if not updated_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return {
        "message": "Profile updated successfully",
        "user": {
            "id": str(updated_user["_id"]),
            "name": updated_user["name"],
            "email": updated_user["email"],
            "is_google_user": updated_user.get("is_google_user", False),
            "created_at": updated_user["created_at"],
            "preferences": updated_user.get("preferences", UserPreferences().model_dump())
        }
    }


# DELETE current user account
@router.delete("/me")
async def delete_me(
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: DELETE /users/me
        - Permanently deletes the user account
        - Requires JWT token
    """
    user_id = str(current_user["_id"])

    # Call CRUD function to delete user
    deleted = await delete_user(user_id)

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return {"message": "Account deleted successfully"}


# PATCH preferences (partial update — only provided fields change)
@router.patch("/me/preferences")
async def update_preferences(
    body: UserPreferencesUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_database()
    patch = {
        f"preferences.{k}": v
        for k, v in body.model_dump(exclude_none=True).items()
    }
    if patch:
        await db["users"].update_one(
            {"_id": ObjectId(str(current_user["_id"]))},
            {"$set": patch},
        )
    return {"message": "Preferences updated"}


# CHANGE PASSWORD
class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

@router.patch("/me/password")
async def change_password(
    body: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):
    if current_user.get("is_google_user"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google accounts cannot change password here"
        )
    if not verify_password(body.current_password, current_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    if len(body.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters"
        )
    db = get_database()
    await db["users"].update_one(
        {"_id": ObjectId(str(current_user["_id"]))},
        {"$set": {"password_hash": hash_password(body.new_password)}}
    )
    return {"message": "Password changed successfully"}
class QuizPreferencesRequest(BaseModel):
    goals: List[str] = []
    scheduleType: Optional[str] = None
    dailyTaskLoad: int = 5
    productivityChallenges: List[str] = []

@router.post("/me/quiz")
async def save_quiz_preferences(
    body: QuizPreferencesRequest,
    current_user: dict = Depends(get_current_user)
):
    """Save onboarding quiz preferences"""
    db = get_database()
    await db["users"].update_one(
        {"_id": ObjectId(str(current_user["_id"]))},
        {"$set": {
            "quiz_preferences": {
                "goals": body.goals,
                "scheduleType": body.scheduleType,
                "dailyTaskLoad": body.dailyTaskLoad,
                "productivityChallenges": body.productivityChallenges,
                "quizCompleted": True
            }
        }}
    )
    return {"message": "Quiz preferences saved successfully"}