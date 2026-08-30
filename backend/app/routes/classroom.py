# Purpose: API endpoints for Google Classroom integration
# Endpoints:
#   POST /classroom/connect - Store OAuth tokens
#   GET /classroom/oauth/url - Get Google OAuth URL (deprecated - use mobile-auth)
#   GET /classroom/oauth/mobile-auth - Get OAuth URL for mobile app
#   GET /classroom/oauth/callback - Handle OAuth callback (web)
#   GET /classroom/oauth/mobile-callback - Handle OAuth callback for mobile
#   GET /classroom/courses - Get user's courses
#   PUT /classroom/courses/{id}/toggle - Enable/disable sync
#   DELETE /classroom/courses/{id}/archive - Archive course
#   POST /classroom/courses/{id}/restore - Restore archived course
#   GET /classroom/courses/{id}/assignments - Get assignments
#   POST /classroom/sync - Manual sync all enabled courses
#   POST /classroom/submit/text - Submit text assignment
#   POST /classroom/submit/file - Submit file assignment
#   GET /classroom/health - Check connection status

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import asyncio
import base64
import hashlib
import secrets
from bson import ObjectId
from google_auth_oauthlib.flow import Flow
from app.db.connection import get_database
from app.utils.dependencies import get_current_user
from app.services.google_classroom import GoogleClassroomService
from app.crud.task import create_task
from app.crud import sync_dismissals
from app.models.task import TaskCreate
from app.config import settings

router = APIRouter(prefix="/classroom", tags=["Google Classroom"])

# Google Classroom OAuth scopes
SCOPES = [
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.me',
    'https://www.googleapis.com/auth/classroom.coursework.students',
    'https://www.googleapis.com/auth/classroom.rosters.readonly'
]

# Redirect URIs
WEB_REDIRECT_URI = f"{settings.API_URL}/classroom/oauth/callback"
MOBILE_REDIRECT_URI = f"{settings.API_URL}/classroom/oauth/mobile-callback"


def get_flow(redirect_uri: str = None):
    """Create OAuth flow instance"""
    return Flow.from_client_config(
        {
            "web": {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [WEB_REDIRECT_URI, MOBILE_REDIRECT_URI]
            }
        },
        scopes=SCOPES,
        redirect_uri=redirect_uri or WEB_REDIRECT_URI
    )


def create_pkce_pair():
    """Create a PKCE verifier/challenge pair for the mobile OAuth flow."""
    code_verifier = secrets.token_urlsafe(96)
    code_challenge = base64.urlsafe_b64encode(
        hashlib.sha256(code_verifier.encode("utf-8")).digest()
    ).decode("utf-8").rstrip("=")
    return code_verifier, code_challenge


# ─────────────────────────────────────────────────────────────────
# REQUEST / RESPONSE MODELS
# ─────────────────────────────────────────────────────────────────

class ToggleCourseRequest(BaseModel):
    enabled: bool


class ConnectClassroomRequest(BaseModel):
    access_token: str
    refresh_token: str


class TextSubmissionRequest(BaseModel):
    course_id: str
    assignment_id: str
    content: str


class FileSubmissionRequest(BaseModel):
    course_id: str
    assignment_id: str
    file_url: str
    file_name: str


# ─────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────

def _priority_from_due_date(due_date: Optional[datetime]) -> str:
    """
    Derive task priority from how soon a Classroom assignment is due:
    - due today or overdue        -> high
    - due within the next 6 days  -> medium
    - due a week or more away     -> low
    No due date keeps the neutral default of medium.
    """
    if due_date is None:
        return "medium"

    days_until = (due_date.date() - datetime.utcnow().date()).days

    if days_until <= 0:
        return "high"
    elif days_until < 7:
        return "medium"
    else:
        return "low"


# Fallback window for assignments with no due date at all — there's no
# "due today or later" to check, so these are judged by how recently they
# were posted/updated instead. Keeps sync from dragging in a whole
# semester/year of finished-course backlog that never had a due date set.
RECENT_ASSIGNMENT_CUTOFF_DAYS = 30


def _is_recent_assignment(assignment: Dict[str, Any], cutoff_days: int = RECENT_ASSIGNMENT_CUTOFF_DAYS) -> bool:
    """
    True if a Classroom assignment counts as "latest" rather than old
    backlog from a past course or semester.
    - Has a due date -> latest only if that date is today or in the future.
      Anything already overdue, even by a day, is old — no trailing grace
      window, by design (a 30-day trailing window was still pulling in
      assignments overdue by over a week).
    - No due date at all -> fall back to how recently it was posted/updated
      (within cutoff_days), since there's no due date to judge by.
    - Nothing usable at all -> don't silently drop it
    """
    today = datetime.utcnow().date()

    due = assignment.get('dueDate')
    if due:
        try:
            due_date = datetime(
                due.get('year', 2024), due.get('month', 1), due.get('day', 1)
            ).date()
            return due_date >= today
        except (ValueError, TypeError):
            pass  # unparsable due date — fall through to posted/updated time

    cutoff = datetime.utcnow() - timedelta(days=cutoff_days)
    timestamp_str = assignment.get('updateTime') or assignment.get('creationTime')
    if timestamp_str:
        try:
            ts = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00')).replace(tzinfo=None)
            return ts >= cutoff
        except ValueError:
            pass

    return True


async def get_synced_courses(db, user_id: str) -> Dict[str, Dict]:
    """Get synced courses as a dictionary keyed by course_id"""
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return {}

    classroom_settings = user.get('classroom_settings', {})
    synced_courses = classroom_settings.get('synced_courses', {})

    # If it's an array (old format), convert to dict on the fly
    if isinstance(synced_courses, list):
        new_format = {}
        for course in synced_courses:
            if course.get('course_id'):
                new_format[course['course_id']] = {
                    'course_id': course['course_id'],
                    'enabled': course.get('enabled', True),
                    'archived': course.get('archived', False),
                    'last_sync': course.get('last_sync')
                }
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"classroom_settings.synced_courses": new_format}}
        )
        return new_format

    return synced_courses


async def update_course_sync_status(db, user_id: str, course_id: str, data: Dict[str, Any]):
    """Update sync status for a specific course"""
    synced_courses = await get_synced_courses(db, user_id)

    if course_id not in synced_courses:
        synced_courses[course_id] = {'course_id': course_id}

    synced_courses[course_id].update(data)
    synced_courses[course_id]['updated_at'] = datetime.utcnow()

    await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"classroom_settings.synced_courses": synced_courses}}
    )


async def store_oauth_tokens(db, user_id: str, credentials):
    """Store OAuth tokens for user"""
    await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {
            "classroom_tokens": {
                "access_token": credentials.token,
                "refresh_token": credentials.refresh_token,
                # credentials.expiry is already a naive UTC datetime — store
                # it directly. Round-tripping through .timestamp() treats it
                # as local time and shifts it by the server's UTC offset.
                "expires_at": credentials.expiry,
                "connected_at": datetime.utcnow()
            }
        }}
    )


# ─────────────────────────────────────────────────────────────────
# OAUTH ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/oauth/url")
async def get_oauth_url(current_user: dict = Depends(get_current_user)):
    """Generate Google OAuth URL (deprecated)"""
    flow = get_flow()
    auth_url, state = flow.authorization_url(
        access_type='offline',
        include_granted_scopes='true',
        prompt='consent'
    )
    return {"auth_url": auth_url}


@router.get("/oauth/mobile-auth")
async def mobile_oauth_auth(current_user: dict = Depends(get_current_user)):
    """Generate OAuth URL for mobile app"""
    flow = get_flow(redirect_uri=MOBILE_REDIRECT_URI)

    state = str(ObjectId())
    code_verifier, code_challenge = create_pkce_pair()

    db = get_database()
    await db.oauth_states.insert_one({
        "state": state,
        "user_id": str(current_user["_id"]),
        "service": "google_classroom",
        "code_verifier": code_verifier,
        "created_at": datetime.utcnow()
    })

    auth_url, _ = flow.authorization_url(
        access_type='offline',
        include_granted_scopes='true',
        prompt='consent',
        state=state,
        code_challenge=code_challenge,
        code_challenge_method='S256'
    )

    return {"auth_url": auth_url, "state": state}


@router.get("/oauth/callback")
async def oauth_callback(code: str, state: str = None):
    """Handle OAuth callback for web browser"""
    try:
        flow = get_flow()
        flow.fetch_token(code=code)
        credentials = flow.credentials
        return RedirectResponse(
            url=f"{settings.FRONTEND_URL}/classroom/success"
                f"?access_token={credentials.token}"
                f"&refresh_token={credentials.refresh_token}"
        )
    except Exception as e:
        return RedirectResponse(
            url=f"{settings.FRONTEND_URL}/classroom/error?message={str(e)}"
        )


@router.get("/oauth/mobile-callback")
async def mobile_oauth_callback(code: str, state: str):
    """Handle OAuth callback for mobile app"""
    db = get_database()

    try:
        stored_state = await db.oauth_states.find_one({"state": state})
        if not stored_state:
            return HTMLResponse(content="""
                <html><body style="font-family:sans-serif;text-align:center;padding:40px">
                <h2>Connection Failed</h2>
                <p>Invalid or expired session. Please try again.</p>
                </body></html>
            """, status_code=400)

        user_id = stored_state["user_id"]
        code_verifier = stored_state.get("code_verifier")
        await db.oauth_states.delete_one({"state": state})

        flow = get_flow(redirect_uri=MOBILE_REDIRECT_URI)
        flow.fetch_token(code=code, code_verifier=code_verifier)
        credentials = flow.credentials

        await store_oauth_tokens(db, user_id, credentials)

        return HTMLResponse(content="""
            <html>
            <body style="font-family:sans-serif;text-align:center;
                         padding:40px;background:#f0f4ff">
              <div style="margin-top:80px">
                <h2 style="color:#1360E2">✅ Connected!</h2>
                <p>Google Classroom connected successfully.</p>
                <p style="color:#64748B">You can now return to the app.</p>
              </div>
            </body>
            </html>
        """)

    except Exception as e:
        return HTMLResponse(content=f"""
            <html><body style="font-family:sans-serif;text-align:center;padding:40px">
            <h2 style="color:#E53E3E">Connection Failed</h2>
            <p>{str(e)}</p>
            </body></html>
        """, status_code=400)


@router.post("/connect")
async def connect_classroom(
    request: ConnectClassroomRequest,
    current_user: dict = Depends(get_current_user)
):
    """Store Google Classroom OAuth tokens (manual fallback)"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])

    await db.users.update_one(
        {"_id": user_id},
        {"$set": {
            "classroom_tokens": {
                "access_token": request.access_token,
                "refresh_token": request.refresh_token,
                "connected_at": datetime.utcnow()
            }
        }}
    )
    return {"message": "Google Classroom connected successfully"}


# ─────────────────────────────────────────────────────────────────
# COURSE ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.get("/courses")
async def get_courses(current_user: dict = Depends(get_current_user)):
    """Get all courses from Google Classroom with sync status"""
    db = get_database()
    user_id = str(current_user["_id"])

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'classroom_tokens' in user if user else False

    if not has_tokens:
        return {"courses": [], "connected": False}

    courses = await GoogleClassroomService.fetch_courses(user_id, db)
    synced_courses = await get_synced_courses(db, user_id)

    for course in courses:
        course_id = course.get('id')
        course_settings = synced_courses.get(course_id, {})
        course['enabled'] = course_settings.get('enabled', True)
        course['archived'] = course_settings.get('archived', False)
        course['last_sync'] = course_settings.get('last_sync')

    return {"courses": courses, "connected": True}


@router.put("/courses/{course_id}/toggle")
async def toggle_course_sync(
    course_id: str,
    request: ToggleCourseRequest,
    current_user: dict = Depends(get_current_user)
):
    """Enable or disable sync for a specific course"""
    db = get_database()
    user_id = str(current_user["_id"])

    await update_course_sync_status(
        db, user_id, course_id,
        {'enabled': request.enabled}
    )

    return {"message": "Course sync status updated", "enabled": request.enabled}


@router.delete("/courses/{course_id}/archive")
async def archive_course(
    course_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Archive a course"""
    db = get_database()
    user_id = str(current_user["_id"])

    await update_course_sync_status(
        db, user_id, course_id,
        {'archived': True, 'enabled': False}
    )

    return {"message": "Course archived"}


@router.post("/courses/{course_id}/restore")
async def restore_course(
    course_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Restore an archived course"""
    db = get_database()
    user_id = str(current_user["_id"])

    await update_course_sync_status(
        db, user_id, course_id,
        {'archived': False}
    )

    return {"message": "Course restored successfully"}


@router.get("/courses/{course_id}/assignments")
async def get_course_assignments(
    course_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get assignments for a specific course"""
    db = get_database()
    user_id = str(current_user["_id"])

    assignments = await GoogleClassroomService.fetch_assignments(
        user_id, course_id, db
    )

    for assignment in assignments:
        existing = await db.tasks.find_one({
            "user_id": user_id,
            "source_id": assignment['id'],
            "source": "google_classroom"
        })
        assignment['is_synced'] = existing is not None

    return {"assignments": assignments}


# ─────────────────────────────────────────────────────────────────
# SYNC ENDPOINT  ← MAIN FIX IS HERE
# ─────────────────────────────────────────────────────────────────

@router.post("/sync")
async def sync_assignments(current_user: dict = Depends(get_current_user)):
    """Sync all assignments from enabled courses"""
    db = get_database()
    user_id = str(current_user["_id"])

    # Get explicitly configured courses
    synced_courses = await get_synced_courses(db, user_id)

    # ✅ Fix 1: if user never toggled anything, fall back to ALL Google courses
    if not synced_courses:
        print("📋 No synced_courses config found — fetching all courses from Google")
        all_courses = await GoogleClassroomService.fetch_courses(user_id, db)
        enabled_course_ids = [course['id'] for course in all_courses]
        print(f"✅ Will sync {len(enabled_course_ids)} courses")
    else:
        enabled_course_ids = [
            course_id for course_id, config in synced_courses.items()
            if config.get('enabled', True) and not config.get('archived', False)
        ]
        print(f"✅ Will sync {len(enabled_course_ids)} enabled courses")

    new_tasks_count = 0
    synced_assignments = []
    errors = []

    # Assignments the user explicitly deleted before — don't resurrect them.
    dismissed_ids = await sync_dismissals.get_dismissed_source_ids(user_id, "google_classroom")

    # Fetch every course's assignments concurrently instead of one at a
    # time — this was a sequential chain of blocking Google API round
    # trips, so N courses meant N times the wait for no reason (each
    # course's fetch is independent of the others).
    assignments_by_course = await asyncio.gather(
        *(GoogleClassroomService.fetch_assignments(user_id, cid, db) for cid in enabled_course_ids),
        return_exceptions=True,
    )

    for course_id, assignments in zip(enabled_course_ids, assignments_by_course):
        if isinstance(assignments, Exception):
            print(f"❌ Error syncing course {course_id}: {assignments}")
            errors.append(str(assignments))
            continue

        try:
            print(f"📖 Course {course_id}: found {len(assignments)} assignments")

            for assignment in assignments:
                assignment_id = assignment.get('id')

                # ✅ Fix 2: use string user_id (matches how create_task stores it)
                existing_task = await db.tasks.find_one({
                    "user_id": user_id,
                    "source_id": assignment_id,
                    "source": "google_classroom"
                })

                if not existing_task:
                    if assignment_id in dismissed_ids:
                        print(f"🚫 Skipping user-deleted assignment: {assignment.get('title')}")
                        continue

                    if not _is_recent_assignment(assignment):
                        print(f"⏳ Skipping old assignment (outside {RECENT_ASSIGNMENT_CUTOFF_DAYS}-day window): {assignment.get('title')}")
                        continue

                    # Parse due date safely
                    due_date = None
                    if assignment.get('dueDate'):
                        due = assignment['dueDate']
                        try:
                            due_date = datetime(
                                due.get('year', 2024),
                                due.get('month', 1),
                                due.get('day', 1)
                            )
                        except Exception as date_err:
                            print(f"⚠️ Could not parse due date: {date_err}")
                            due_date = None

                    task_data = TaskCreate(
                        title=assignment.get('title', 'Untitled Assignment'),
                        description=assignment.get('description', ''),
                        priority=_priority_from_due_date(due_date),
                        category="classroom",
                        due_date=due_date,
                        source="google_classroom",
                        source_id=assignment_id,
                        course_id=course_id,
                        skip_date_validation=True,
                    )

                    await create_task(task_data, user_id)
                    new_tasks_count += 1
                    synced_assignments.append(assignment.get('title'))
                    print(f"✅ Created task: {assignment.get('title')}")
                else:
                    print(f"⏭️ Already exists: {assignment.get('title')}")

            # Update last sync time for this course
            await update_course_sync_status(
                db, user_id, course_id,
                {'last_sync': datetime.utcnow()}
            )

        except Exception as course_err:
            print(f"❌ Error syncing course {course_id}: {course_err}")
            errors.append(str(course_err))
            continue  # don't let one failed course stop others

    print(f"🎯 Sync complete: {new_tasks_count} new tasks created")
    return {
        "message": f"Sync completed. {new_tasks_count} new assignments added.",
        "new_tasks_count": new_tasks_count,
        "synced_assignments": synced_assignments,
        "errors": errors if errors else None
    }


# ─────────────────────────────────────────────────────────────────
# SUBMISSION ENDPOINTS
# ─────────────────────────────────────────────────────────────────

@router.post("/submit/text")
async def submit_text(
    request: TextSubmissionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Submit a text answer to a Google Classroom assignment"""
    db = get_database()
    user_id = str(current_user["_id"])

    try:
        result = await GoogleClassroomService.submit_text_submission(
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
        result = await GoogleClassroomService.submit_file_submission(
            user_id=user_id,
            course_id=request.course_id,
            assignment_id=request.assignment_id,
            file_url=request.file_url,
            db=db
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─────────────────────────────────────────────────────────────────
# HEALTH & DISCONNECT
# ─────────────────────────────────────────────────────────────────

@router.get("/health")
async def classroom_health(current_user: dict = Depends(get_current_user)):
    """Check if Classroom integration is working"""
    db = get_database()
    user_id = str(current_user["_id"])

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    has_tokens = 'classroom_tokens' in user if user else False

    return {
        "connected": has_tokens,
        "message": "Classroom integration is ready" if has_tokens
                   else "Not connected to Google Classroom"
    }


@router.post("/disconnect")
async def disconnect_classroom(current_user: dict = Depends(get_current_user)):
    """Disconnect Google Classroom account"""
    db = get_database()
    user_id = ObjectId(current_user["_id"])

    await db.users.update_one(
        {"_id": user_id},
        {"$unset": {"classroom_tokens": "", "classroom_settings": ""}}
    )

    return {"message": "Google Classroom disconnected successfully"}