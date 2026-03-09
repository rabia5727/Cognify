from fastapi import APIRouter, HTTPException, status, Depends
from app.utils.dependencies import get_current_user
from app.models.user import UserUpdate, UserResponse, UserPreferences
from app.crud.user import update_user, delete_user

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
        "preferences": current_user.get("preferences", UserPreferences().model_dump())
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