from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from bson import ObjectId
import os

class GoogleDriveService:
    SCOPES = [
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.readonly',
    ]
    
    @staticmethod
    async def get_drive_service(user_id: str, db):
        """Get authenticated Google Drive service"""
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or 'drive_tokens' not in user:
            return None
        
        tokens = user['drive_tokens']
        creds = Credentials(
            token=tokens.get('access_token'),
            refresh_token=tokens.get('refresh_token'),
            token_uri='https://oauth2.googleapis.com/token',
            client_id=settings.GOOGLE_DRIVE_CLIENT_ID,
            client_secret=settings.GOOGLE_DRIVE_CLIENT_SECRET,
            scopes=GoogleDriveService.SCOPES
        )
        
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {"drive_tokens.access_token": creds.token}}
            )
        
        return build('drive', 'v3', credentials=creds)
    
    @staticmethod
    async def upload_file(user_id: str, db, file_path: str, file_name: str, mime_type: str = None):
        """Upload a file to Google Drive"""
        service = await GoogleDriveService.get_drive_service(user_id, db)
        if not service:
            raise Exception("Google Drive not connected")
        
        # Create folder for app if not exists
        folder_id = await GoogleDriveService._get_or_create_app_folder(service, user_id)
        
        file_metadata = {
            'name': file_name,
            'parents': [folder_id]
        }
        
        media = MediaFileUpload(file_path, mimetype=mime_type)
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id,webViewLink'
        ).execute()
        
        return {
            'file_id': file.get('id'),
            'web_view_link': file.get('webViewLink'),
            'share_link': f'https://drive.google.com/file/d/{file.get("id")}/view'
        }
    
    @staticmethod
    async def _get_or_create_app_folder(service, user_id):
        """Get or create Cognify app folder in Drive"""
        # Search for existing folder
        results = service.files().list(
            q="name='Cognify' and mimeType='application/vnd.google-apps.folder' and trashed=false",
            spaces='drive',
            fields='files(id, name)'
        ).execute()
        
        folders = results.get('files', [])
        if folders:
            return folders[0]['id']
        
        # Create new folder
        folder_metadata = {
            'name': 'Cognify',
            'mimeType': 'application/vnd.google-apps.folder'
        }
        folder = service.files().create(body=folder_metadata, fields='id').execute()
        return folder.get('id')