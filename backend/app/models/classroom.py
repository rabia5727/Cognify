# Purpose: Pydantic models for request/response validation
# Models:
#   - CourseSyncStatus (course_id, enabled, archived)
#   - ClassroomSettings (user_id, courses list, auto_sync settings)
#   - Assignment (title, due_date, description, course_id)
#   - SubmissionRequest (course_id, assignment_id, content, file_url)