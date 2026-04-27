# Purpose: Core Google API integration
# Methods:
#   - get_authenticated_service() - Get Google API client
#   - fetch_courses() - Get all courses for user
#   - fetch_assignments() - Get assignments for specific course
#   - create_task_from_assignment() - Convert assignment to task
#   - sync_new_assignments() - Find and create tasks for new assignments
#   - submit_text_submission() - Submit text answer
#   - submit_file_submission() - Upload file to Drive and submit
import httpx
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from bson import ObjectId

class GoogleClassroomService:
    SCOPES = [
        'https://www.googleapis.com/auth/classroom.courses.readonly',
        'https://www.googleapis.com/auth/classroom.coursework.me',
        'https://www.googleapis.com/auth/classroom.coursework.students',
        'https://www.googleapis.com/auth/classroom.rosters.readonly'
    ]
    
    @staticmethod
    async def get_classroom_service(user_id: str, db):
        """Get authenticated Google Classroom service for user"""
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or 'classroom_tokens' not in user:
            return None
        
        tokens = user['classroom_tokens']
        creds = Credentials(
            token=tokens.get('access_token'),
            refresh_token=tokens.get('refresh_token'),
            token_uri='https://oauth2.googleapis.com/token',
            client_id=tokens.get('client_id'),
            client_secret=tokens.get('client_secret'),
            scopes=GoogleClassroomService.SCOPES
        )
        
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            # Update tokens in database
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {"classroom_tokens.access_token": creds.token}}
            )
        
        return build('classroom', 'v1', credentials=creds)
    
    @staticmethod
    async def fetch_courses(user_id: str, db):
        """Fetch all courses for user"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            return []
        
        try:
            results = service.courses().list(pageSize=50).execute()
            return results.get('courses', [])
        except Exception as e:
            print(f"Error fetching courses: {e}")
            return []
    
    @staticmethod
    async def fetch_assignments(user_id: str, course_id: str, db):
        """Fetch assignments for a specific course"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            return []
        
        try:
            results = service.courses().list(pageSize=50).execute()
            return results.get('courses', [])
        except Exception as e:
            print(f"Error fetching courses: {e}")
            return []

    @staticmethod
    async def fetch_assignments(user_id: str, course_id: str, db):
        """Fetch assignments for a specific course"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            return []
        try:
            results = service.courses().list(pageSize=50).execute()
            return results.get('courses', [])
        except Exception as e:
            print(f"Error fetching courses: {e}")
            return []

    @staticmethod
    async def fetch_assignments(user_id: str, course_id: str, db):
        """Fetch assignments for a specific course"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            return []
        try:
            results = service.courses().courseWork().list(
                courseId=course_id,
                courseWorkStates='PUBLISHED'
            ).execute()
            return results.get('courseWork', [])
        except Exception as e:
            print(f"Error fetching assignments for course {course_id}: {e}")
            return []