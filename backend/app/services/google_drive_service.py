from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseUpload
from bson import ObjectId
import io
import os
from datetime import datetime
from app.config import settings

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
            client_id=settings.GOOGLE_CLIENT_ID,
            client_secret=settings.GOOGLE_CLIENT_SECRET,
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
    async def disconnect(user_id: str, db):
        """Remove Google Drive tokens from database"""
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$unset": {"drive_tokens": ""}}
        )
        return {"message": "Google Drive disconnected successfully"}
    
    @staticmethod
    async def _get_or_create_app_folder(service) -> str:
        """Get or create Cognify folder in Google Drive"""
        # Search for existing Cognify folder
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
    
    @staticmethod
    async def upload_file(
        user_id: str, 
        db, 
        file_content: bytes, 
        file_name: str, 
        mime_type: str = 'application/pdf'
    ) -> dict:
        """Upload a file to Google Drive"""
        service = await GoogleDriveService.get_drive_service(user_id, db)
        if not service:
            raise Exception("Google Drive not connected")
        
        # Get or create Cognify folder
        folder_id = await GoogleDriveService._get_or_create_app_folder(service)
        
        # Upload file
        file_metadata = {
            'name': file_name,
            'parents': [folder_id]
        }
        
        # Use BytesIO for in-memory file
        file_stream = io.BytesIO(file_content)
        media = MediaIoBaseUpload(file_stream, mimetype=mime_type, resumable=True)
        
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id,webViewLink,size'
        ).execute()
        
        return {
            'file_id': file.get('id'),
            'web_view_link': file.get('webViewLink'),
            'share_link': f'https://drive.google.com/file/d/{file.get("id")}/view',
            'size': file.get('size')
        }
    
    @staticmethod
    async def upload_text_as_pdf(
        user_id: str,
        db,
        content: str,
        file_name: str
    ) -> dict:
        """Upload text content as a PDF file to Google Drive"""
        from reportlab.pdfgen import canvas
        from reportlab.lib.pagesizes import letter
        from reportlab.lib.units import inch
        import io
        
        # Create PDF in memory
        buffer = io.BytesIO()
        c = canvas.Canvas(buffer, pagesize=letter)
        width, height = letter
        
        # Add text content
        y = height - inch
        for line in content.split('\n'):
            if y < inch:
                c.showPage()
                y = height - inch
            c.drawString(inch, y, line[:100])  # Truncate long lines
            y -= 15
        
        c.save()
        
        # Get PDF content
        pdf_content = buffer.getvalue()
        buffer.close()
        
        # Upload to Drive
        return await GoogleDriveService.upload_file(
            user_id=user_id,
            db=db,
            file_content=pdf_content,
            file_name=f"{file_name}.pdf" if not file_name.endswith('.pdf') else file_name,
            mime_type='application/pdf'
        )
    
    @staticmethod
    async def upload_text_as_doc(
        user_id: str,
        db,
        content: str,
        file_name: str
    ) -> dict:
        """Upload text content as a Google Doc to Google Drive"""
        service = await GoogleDriveService.get_drive_service(user_id, db)
        if not service:
            raise Exception("Google Drive not connected")
        
        # Get or create Cognify folder
        folder_id = await GoogleDriveService._get_or_create_app_folder(service)
        
        # Create Google Doc
        file_metadata = {
            'name': file_name,
            'parents': [folder_id],
            'mimeType': 'application/vnd.google-apps.document'
        }
        
        file = service.files().create(
            body=file_metadata,
            fields='id,webViewLink'
        ).execute()
        
        # Add content to the document
        doc_content = f'<html><body><pre>{content}</pre></body></html>'
        service.files().update(
            fileId=file.get('id'),
            media_body=MediaIoBaseUpload(
                io.BytesIO(doc_content.encode('utf-8')),
                mimetype='text/html'
            )
        ).execute()
        
        return {
            'file_id': file.get('id'),
            'web_view_link': file.get('webViewLink'),
            'share_link': f'https://drive.google.com/file/d/{file.get("id")}/view'
        }