# Purpose: API endpoints
# Endpoints:
#   POST /classroom/connect - Store OAuth tokens
#   GET /classroom/oauth/url - Get Google OAuth URL
#   GET /classroom/oauth/callback - Handle OAuth callback
#   GET /classroom/courses - Get user's courses
#   PUT /classroom/courses/{id}/toggle - Enable/disable sync
#   DELETE /classroom/courses/{id}/archive - Archive course
#   GET /classroom/courses/{id}/assignments - Get assignments
#   POST /classroom/sync - Manual sync all enabled courses
#   POST /classroom/submit - Submit assignment
#  POST /classroom/courses/{id}/restore - Restore archived course

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from bson import ObjectId
from google_auth_oauthlib.flow import Flow

from ..db.connection import get_database
from ..utils.dependencies import get_current_user
from ..services.google_classroom import GoogleClassroomService
from ..crud.task import create_task
from ..models.task import TaskCreate
from ..config import settings

router = APIRouter(prefix="/classroom", tags=["Google Classroom"])

# Google Classroom OAuth scopes
SCOPES = [
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.me',
    'https://www.googleapis.com/auth/classroom.coursework.students',
    'https://www.googleapis.com/auth/classroom.rosters.readonly'
]

REDIRECT_URI = "http://localhost:8000/classroom/oauth/callback"

def get_flow():
    """Create OAuth flow instance"""
    return Flow.from_client_config(
        {
            "web": {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [REDIRECT_URI]
            }
        },
        scopes=SCOPES,
        redirect_uri=REDIRECT_URI
    )


class ToggleCourseRequest(BaseModel):
    enabled: bool


class ConnectClassroomRequest(BaseModel):
    access_token: str
    refresh_token: str
    client_id: str
    client_secret: str


# ─────────────────────────────────────────────────────────────────
# OAUTH ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/oauth/url")
async def get_oauth_url(current_user: dict = Depends(get_current_user)):
    """Generate Google OAuth URL for user to authorize Classroom access"""
    flow = get_flow()
    auth_url, state = flow.authorization_url(
        access_type='offline',         # Get refresh token for long-term access
        include_granted_scopes='true',
        prompt='consent'               # Always show consent screen
    )
    return {"auth_url": auth_url}


@router.get("/oauth/callback")
async def oauth_callback(code: str):
    """
    Handle Google OAuth callback and return tokens
    Google redirects here after user grants permission
    """
    try:
        flow = get_flow()
        # Exchange authorization code for tokens
        flow.fetch_token(code=code)
        credentials = flow.credentials

        # Return tokens to Flutter app
        # Flutter will then call POST /classroom/connect to store them
        return {
            "access_token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "message": "Successfully connected to Google Classroom! Copy these tokens and use POST /classroom/connect to save them."
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"OAuth failed: {str(e)}")


# ─────────────────────────────────────────────────────────────────
# EXISTING ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/courses")
async def get_courses(current_user: dict = Depends(get_current_user)):
    """Get all courses from Google Classroom"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    courses = await GoogleClassroomService.fetch_courses(user_id, db)
    
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    settings_data = user.get('classroom_settings', {}) if user else {}
    synced_courses = settings_data.get('synced_courses', [])
    
    for course in courses:
        course_id = course.get('id')
        course_settings = next((c for c in synced_courses if c.get('course_id') == course_id), {})
        course['enabled'] = course_settings.get('enabled', True)
        course['archived'] = course_settings.get('archived', False)
        course['last_sync'] = course_settings.get('last_sync')
    
    return {"courses": courses}


@router.put("/courses/{course_id}/toggle")
async def toggle_course_sync(
    course_id: str,
    request: ToggleCourseRequest,
    current_user: dict = Depends(get_current_user)
):
    """Enable or disable sync for a specific course"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])
    
    result = await db.users.update_one(
        {"_id": user_id},
        {
            "$set": {
                f"classroom_settings.synced_courses.{course_id}.enabled": request.enabled,
                f"classroom_settings.synced_courses.{course_id}.course_id": course_id
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to update course status")
    
    return {"message": "Course sync status updated"}


@router.delete("/courses/{course_id}/archive")
async def archive_course(
    course_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Archive a course (hide from active list)"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])
    
    result = await db.users.update_one(
        {"_id": user_id},
        {"$set": {f"classroom_settings.synced_courses.{course_id}.archived": True}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to archive course")
    
    return {"message": "Course archived"}


@router.post("/sync")
async def sync_assignments(current_user: dict = Depends(get_current_user)):
    """Sync all assignments from enabled courses"""
    db = get_database()
    user_id = str(current_user["_id"])
    
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    settings_data = user.get('classroom_settings', {})
    synced_courses = settings_data.get('synced_courses', [])
    
    enabled_courses = [c for c in synced_courses if c.get('enabled', True) and not c.get('archived', False)]
    
    new_tasks_count = 0
    
    for course in enabled_courses:
        course_id = course.get('course_id')
        assignments = await GoogleClassroomService.fetch_assignments(user_id, course_id, db)
        
        for assignment in assignments:
            assignment_id = assignment.get('id')
            existing_task = await db.tasks.find_one({
                "user_id": user_id,
                "source_id": assignment_id,
                "source": "google_classroom"
            })
            
            if not existing_task:
                task_data = TaskCreate(
                    title=assignment.get('title', 'Untitled Assignment'),
                    description=assignment.get('description', ''),
                    priority="high",
                    category="academic",
                    due_date=assignment.get('dueDate'),
                    source="google_classroom",
                    source_id=assignment_id,
                    course_id=course_id
                )
                await create_task(task_data, user_id)
                new_tasks_count += 1
        
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {f"classroom_settings.synced_courses.{course_id}.last_sync": datetime.utcnow()}}
        )
    
    return {
        "message": f"Sync completed. {new_tasks_count} new assignments added.",
        "new_tasks_count": new_tasks_count
    }


@router.post("/connect")
async def connect_classroom(
    request: ConnectClassroomRequest,
    current_user: dict = Depends(get_current_user)
):
    """Store Google Classroom OAuth tokens for user"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])

    await db.users.update_one(
        {"_id": user_id},
        {"$set": {
            "classroom_tokens": {
                "access_token": request.access_token,
                "refresh_token": request.refresh_token,
                "client_id": request.client_id,
                "client_secret": request.client_secret,
            }
        }}
    )
    return {"message": "Google Classroom connected successfully"}


@router.post("/courses/{course_id}/restore")
async def restore_course(
    course_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Restore an archived course"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])

    result = await db.users.update_one(
        {"_id": user_id},
        {"$set": {f"classroom_settings.synced_courses.{course_id}.archived": False}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to restore course")

    return {"message": "Course restored successfully"}
#submission to the classroom assignments through text or file link (for simplicity, we are not handling actual file uploads here, just links to files)
class TextSubmissionRequest(BaseModel):
    course_id: str
    assignment_id: str
    content: str

class FileSubmissionRequest(BaseModel):
    course_id: str
    assignment_id: str
    file_url: str
    file_name: str

@router.post("/submit/text")
async def submit_text(
    request: TextSubmissionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Submit a text answer to a Google Classroom assignment"""
    db = get_database()
    user_id = str(current_user["_id"])
    try:
        result = await GoogleClassroomService.submit_text_assignment(
            user_id=user_id,
            course_id=request.course_id,
            assignment_id=request.assignment_id,
            text=request.content,
            db=db
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/submit/file")
async def submit_file(
    request: FileSubmissionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Submit a file link to a Google Classroom assignment"""
    db = get_database()
    user_id = str(current_user["_id"])
    try:
        result = await GoogleClassroomService.submit_file_assignment(
            user_id=user_id,
            course_id=request.course_id,
            assignment_id=request.assignment_id,
            file_url=request.file_url,
            file_name=request.file_name,
            db=db
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))