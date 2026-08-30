# Purpose: Core Google API integration
# Methods:
#   - get_authenticated_service() - Get Google API client
#   - fetch_courses() - Get all courses for user
#   - fetch_assignments() - Get assignments for specific course
#   - fetch_assignment_submissions() - Get student's submissions
#   - submit_text_submission() - Submit text answer
#   - submit_file_submission() - Upload file to Drive and submit
#
# IMPORTANT: googleapiclient is a synchronous library — every .execute()
# call is a *blocking* network request. Calling it directly inside an
# async def freezes the entire FastAPI event loop for the duration of that
# call, stalling every other request the server is handling (verified:
# a single Gmail sync blocked an unrelated GET / for ~10s). All calls here
# go through asyncio.to_thread() so they run on a worker thread instead.
import asyncio
import httpx
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from bson import ObjectId
from app.config import settings

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
        # Tokens minted via "Connect All" were issued under CONNECT_ALL_CLIENT_ID,
        # not GOOGLE_CLIENT_ID — refreshing under the wrong client gets
        # rejected by Google with "unauthorized_client".
        if tokens.get('oauth_client') == 'connect_all':
            client_id = settings.CONNECT_ALL_CLIENT_ID
            client_secret = settings.CONNECT_ALL_CLIENT_SECRET
        else:
            client_id = settings.GOOGLE_CLIENT_ID
            client_secret = settings.GOOGLE_CLIENT_SECRET

        creds = Credentials(
            token=tokens.get('access_token'),
            refresh_token=tokens.get('refresh_token'),
            token_uri='https://oauth2.googleapis.com/token',
            client_id=client_id,
            client_secret=client_secret,
            scopes=GoogleClassroomService.SCOPES,
            expiry=tokens.get('expires_at')
        )

        if creds.expired and creds.refresh_token:
            await asyncio.to_thread(creds.refresh, Request())
            # Update tokens in database
            # Note: creds.expiry is already a naive UTC datetime — do not
            # round-trip it through .timestamp()/utcfromtimestamp(), which
            # reinterprets naive datetimes as local time and shifts it by
            # the server's UTC offset.
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {"classroom_tokens.access_token": creds.token,
                          "classroom_tokens.expires_at": creds.expiry
                          }}
            )

        return await asyncio.to_thread(build, 'classroom', 'v1', credentials=creds)
    
    @staticmethod
    async def fetch_courses(user_id: str, db):
        """Fetch all courses for user"""
        print("📚 fetch_courses called")
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            print("❌ No service available")
            return []
        
        try:
            results = await asyncio.to_thread(
                service.courses().list(pageSize=50).execute
            )
            courses = results.get('courses', [])
            print(f"✅ Found {len(courses)} courses")
            
            # Process courses to match frontend expectations
            processed_courses = []
            for course in courses:
                processed_courses.append({
                    'id': course.get('id'),
                    'name': course.get('name'),
                    'section': course.get('section', ''),
                    'descriptionHeading': course.get('descriptionHeading', ''),
                    'enrollmentCode': course.get('enrollmentCode', ''),
                    'courseState': course.get('courseState', 'ACTIVE'),
                    'alternateLink': course.get('alternateLink', ''),
                    'teacherFolder': course.get('teacherFolder', {}),
                    'courseMaterialSets': course.get('courseMaterialSets', [])
                })
            return processed_courses
        except Exception as e:
            print(f"❌ Error fetching courses: {e}")
            return []
    
    @staticmethod
    async def fetch_assignments(user_id: str, course_id: str, db):
        """Fetch assignments for a specific course"""
        print(f"🔍 fetch_assignments called for course: {course_id}")
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            print("❌ No service available")
            return []
        
        try:
            print(f"📡 Calling Google Classroom API for course: {course_id}")
            results = await asyncio.to_thread(
                service.courses().courseWork().list(
                    courseId=course_id,
                    courseWorkStates='PUBLISHED'
                ).execute
            )

            assignments = results.get('courseWork', [])
            print(f"✅ Found {len(assignments)} assignments in course {course_id}")
            
            # Print first 3 assignments for debugging
            if assignments:
                print(f"📝 First 3 assignments:")
                for i, assignment in enumerate(assignments[:3]):
                    print(f"   {i+1}. {assignment.get('title')} (ID: {assignment.get('id')})")
                    print(f"      State: {assignment.get('state')}")
                    print(f"      Due: {assignment.get('dueDate')}")
            else:
                print("⚠️ No PUBLISHED assignments found in this course")
                print("   Check if assignments are PUBLISHED (not DRAFT or SCHEDULED)")
            
            # Process assignments to match frontend expectations
            processed_assignments = []
            for assignment in assignments:
                processed_assignments.append({
                    'id': assignment.get('id'),
                    'title': assignment.get('title'),
                    'description': assignment.get('description', ''),
                    'state': assignment.get('state'),
                    'alternateLink': assignment.get('alternateLink'),
                    'creationTime': assignment.get('creationTime'),
                    'updateTime': assignment.get('updateTime'),
                    'dueDate': assignment.get('dueDate'),
                    'dueTime': assignment.get('dueTime'),
                    'maxPoints': assignment.get('maxPoints', 0),
                    'workType': assignment.get('workType', 'ASSIGNMENT'),
                    'submissionModificationMode': assignment.get('submissionModificationMode', 'MODIFIABLE'),
                })
            return processed_assignments
        except Exception as e:
            print(f"❌ Error fetching assignments for course {course_id}: {e}")
            return []

    @staticmethod
    async def fetch_assignment_submissions(user_id: str, course_id: str, assignment_id: str, db):
        """Fetch student's submission for a specific assignment"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            return None
        
        try:
            results = await asyncio.to_thread(
                service.courses().courseWork().studentSubmissions().list(
                    courseId=course_id,
                    courseWorkId=assignment_id
                ).execute
            )

            submissions = results.get('studentSubmissions', [])
            if submissions:
                return submissions[0]  # Return the first submission
            return None
        except Exception as e:
            print(f"❌ Error fetching submission: {e}")
            return None
    @staticmethod
    async def submit_to_classroom_with_drive_file(
        user_id: str, course_id: str, assignment_id: str, drive_file_id: str, db
    ):
        """
        Attaches a Google Drive file to the student's submission slot
        for this assignment, then marks it as turned in — for real.
        """
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            raise Exception("Google Classroom not connected")

        submission = await GoogleClassroomService.fetch_assignment_submissions(
            user_id, course_id, assignment_id, db
        )
        if not submission:
            raise Exception("Could not find your submission slot for this assignment")

        submission_id = submission.get("id")

        # Attach the uploaded Drive file to the submission
        await asyncio.to_thread(
            service.courses().courseWork().studentSubmissions().modifyAttachments(
                courseId=course_id,
                courseWorkId=assignment_id,
                id=submission_id,
                body={"addAttachments": [{"driveFile": {"id": drive_file_id}}]},
            ).execute
        )

        # Mark the assignment as turned in
        await asyncio.to_thread(
            service.courses().courseWork().studentSubmissions().turnIn(
                courseId=course_id,
                courseWorkId=assignment_id,
                id=submission_id,
                body={},
            ).execute
        )

        return {"success": True, "message": "Assignment submitted to Google Classroom"}

    @staticmethod
    async def submit_text_submission(user_id: str, course_id: str, assignment_id: str, text: str, db):
        """Submit a text submission to Google Classroom"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            raise Exception("Google Classroom not connected")

        try:
            doc = {
                'user_id': ObjectId(user_id) if isinstance(user_id, str) and len(user_id) == 24 else user_id,
                'course_id': course_id,
                'assignment_id': assignment_id,
                'type': 'text',
                'content': text,
                'status': 'recorded',
                'created_at': datetime.utcnow()
            }
            await db.classroom_submissions.insert_one(doc)
            return {'success': True, 'message': 'Submission recorded (simulated)'}
        except Exception as e:
            print(f"❌ Error recording text submission: {e}")
            raise Exception(f"Failed to record submission: {str(e)}")
    
    @staticmethod
    async def submit_file_submission(user_id: str, course_id: str, assignment_id: str, file_url: str, db):
        """Submit a file submission (from Drive) to Google Classroom"""
        service = await GoogleClassroomService.get_classroom_service(user_id, db)
        if not service:
            raise Exception("Google Classroom not connected")

        try:
            doc = {
                'user_id': ObjectId(user_id) if isinstance(user_id, str) and len(user_id) == 24 else user_id,
                'course_id': course_id,
                'assignment_id': assignment_id,
                'type': 'file',
                'file_url': file_url,
                'status': 'recorded',
                'created_at': datetime.utcnow()
            }
            await db.classroom_submissions.insert_one(doc)
            return {'success': True, 'message': 'File submission recorded (simulated)'}
        except Exception as e:
            print(f"❌ Error recording file submission: {e}")
            raise Exception(f"Failed to record file submission: {str(e)}")
    
    @staticmethod
    async def sync_new_assignments(user_id: str, db):
        """Find and sync new assignments from Google Classroom"""
        print("🔄 sync_new_assignments called")
        courses = await GoogleClassroomService.fetch_courses(user_id, db)
        print(f"📚 Processing {len(courses)} courses")
        new_assignments = []
        
        for course in courses:
            course_id = course['id']
            course_name = course.get('name', 'Unknown')
            print(f"  📖 Checking course: {course_name} ({course_id})")
            
            assignments = await GoogleClassroomService.fetch_assignments(user_id, course_id, db)
            print(f"     Found {len(assignments)} assignments in {course_name}")
            
            for assignment in assignments:
                # Check if assignment already exists in Cognify tasks
                existing_task = await db.tasks.find_one({
                    "user_id": ObjectId(user_id),
                    "source_id": assignment['id'],
                    "source": "google_classroom"
                })
                
                if existing_task:
                    print(f"     ⏭️ Assignment already exists: {assignment.get('title')}")
                else:
                    print(f"     ✅ NEW assignment found: {assignment.get('title')}")
                    new_assignments.append({
                        'course': course,
                        'assignment': assignment
                    })
        
        print(f"🎯 Total new assignments to sync: {len(new_assignments)}")
        return new_assignments