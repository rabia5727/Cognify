# Purpose: Gmail API integration - fetch, classify, and store emails
# Methods:
#   - get_gmail_service() - Build authenticated Gmail API client
#   - fetch_emails() - Get recent emails from Gmail API
#   - is_actionable_keyword() - Free keyword/regex check
#   - is_actionable_ai() - AI API fallback check
#   - extract_task_info() - Pull title/date/sender/snippet/thread_id
#   - sync_emails() - Full sync flow: fetch → classify → create tasks

import re
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from bson import ObjectId
import base64
import httpx

from app.config import settings
from app.crud.task import create_task
from app.models.task import TaskCreate

class GmailService:
    SCOPES = [
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/gmail.modify',
    ]
    
    # Actionable keywords
    ACTION_KEYWORDS = [
        r'due\s*(?:date)?',
        r'deadline',
        r'submit',
        r'invoice',
        r'report',
        r'asap',
        r'by\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|tomorrow|\d{1,2}/\d{1,2})',
        r'reminder',
        r'action\s*required',
        r'please\s*(?:review|approve|confirm|send|complete)',
        r'urgent',
        r'task',
        r'assignment',
        r'homework',
        r'project',
        r'deliverable',
        r'milestone',
    ]
    
    # Ignore patterns (newsletters, spam, etc)
    IGNORE_PATTERNS = [
        r'unsubscribe',
        r'newsletter',
        r'marketing',
        r'promotion',
        r'you\s*received\s*a\s*message',
        r'donotreply',
        r'noreply',
    ]

    @staticmethod
    def _client_id() -> str:
        return settings.GMAIL_CLIENT_ID or settings.GOOGLE_CLIENT_ID

    @staticmethod
    def _client_secret() -> str:
        return settings.GMAIL_CLIENT_SECRET or settings.GOOGLE_CLIENT_SECRET
    
    @staticmethod
    async def get_gmail_service(user_id: str, db):
        """Get authenticated Gmail service for user"""
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or 'gmail_tokens' not in user:
            return None
        
        tokens = user['gmail_tokens']
        creds = Credentials(
            token=tokens.get('access_token'),
            refresh_token=tokens.get('refresh_token'),
            token_uri='https://oauth2.googleapis.com/token',
            client_id=GmailService._client_id(),
            client_secret=GmailService._client_secret(),
            scopes=GmailService.SCOPES
        )
        
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {
                    "gmail_tokens.access_token": creds.token,
                    "gmail_tokens.expires_at": datetime.utcfromtimestamp(
                        creds.expiry.timestamp()
                    ) if creds.expiry else None
                }}
            )
        
        return build('gmail', 'v1', credentials=creds)
    
    @staticmethod
    async def fetch_emails(user_id: str, db, max_results: int = 50) -> List[Dict]:
        """Fetch recent emails from Gmail API"""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            return []
        
        try:
            # Get messages from inbox (excluding spam)
            results = service.users().messages().list(
                userId='me',
                maxResults=max_results,
                q='in:inbox -in:spam -in:trash'
            ).execute()
            
            messages = results.get('messages', [])
            if not messages:
                return []
            
            emails = []
            for msg in messages:
                # Get full email details
                email_data = service.users().messages().get(
                    userId='me',
                    id=msg['id'],
                    format='full'
                ).execute()
                
                parsed = GmailService._parse_email(email_data)
                emails.append(parsed)
            
            return emails
            
        except Exception as e:
            print(f"❌ Error fetching emails: {e}")
            return []
    
    @staticmethod
    def _parse_email(email_data: Dict) -> Dict:
        """Parse raw Gmail email data into structured format"""
        payload = email_data.get('payload', {})
        headers = payload.get('headers', [])
        
        # Extract headers
        subject = ''
        sender = ''
        date = ''
        for header in headers:
            name = header.get('name', '').lower()
            if name == 'subject':
                subject = header.get('value', '')
            elif name == 'from':
                sender = header.get('value', '')
            elif name == 'date':
                date = header.get('value', '')
        
        # Get body/snippet
        body = GmailService._get_email_body(payload)
        snippet = email_data.get('snippet', '')
        
        return {
            'id': email_data.get('id'),
            'thread_id': email_data.get('threadId'),
            'subject': subject,
            'sender': sender,
            'date': date,
            'body': body,
            'snippet': snippet,
            'raw': email_data
        }
    
    @staticmethod
    def _get_email_body(payload: Dict) -> str:
        """Extract plain text body from email payload"""
        body = ''
        
        if 'parts' in payload:
            # Multipart email
            for part in payload['parts']:
                mime_type = part.get('mimeType', '')
                if mime_type == 'text/plain':
                    data = part.get('body', {}).get('data', '')
                    if data:
                        try:
                            body += base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                        except:
                            pass
                elif mime_type == 'text/html' and not body:
                    data = part.get('body', {}).get('data', '')
                    if data:
                        try:
                            body += base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                        except:
                            pass
        else:
            # Simple email
            data = payload.get('body', {}).get('data', '')
            if data:
                try:
                    body = base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                except:
                    pass
        
        return body[:5000]  # Limit body size
    
    @staticmethod
    def is_actionable_keyword(text: str) -> Tuple[bool, Dict]:
        """
        Check if email is actionable using keyword matching.
        Returns: (is_actionable, extracted_info)
        """
        text_lower = text.lower()
        
        # Check ignore patterns first
        for pattern in GmailService.IGNORE_PATTERNS:
            if re.search(pattern, text_lower):
                return False, {}
        
        # Check actionable keywords
        matched_keywords = []
        for pattern in GmailService.ACTION_KEYWORDS:
            if re.search(pattern, text_lower):
                matched_keywords.append(pattern)
        
        if not matched_keywords:
            return False, {}
        
        # Extract potential due date
        due_date = None
        date_patterns = [
            r'by\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|tomorrow)',
            r'by\s*(\d{1,2}/\d{1,2})',
            r'due\s*(\d{1,2}/\d{1,2})',
        ]
        for pattern in date_patterns:
            match = re.search(pattern, text_lower)
            if match:
                due_date = match.group(1) if len(match.groups()) > 0 else 'soon'
                break
        
        # Determine priority
        priority = 'medium'
        if any(k in matched_keywords for k in ['urgent', 'asap', 'deadline']):
            priority = 'high'
        elif any(k in matched_keywords for k in ['reminder', 'review']):
            priority = 'medium'
        
        return True, {
            'matched_keywords': matched_keywords,
            'suggested_due_date': due_date,
            'suggested_priority': priority
        }
    
    @staticmethod
    async def is_actionable_ai(text: str) -> Tuple[bool, Dict]:
        """
        Check if email is actionable using Claude/AI.
        Only called if keyword check doesn't find a match.
        """
        try:
            # TODO: Replace with actual Claude API call
            # For now, return a conservative "not actionable"
            # This will be implemented when AI assistant is ready
            return False, {}
            
        except Exception as e:
            print(f"❌ AI check failed: {e}")
            return False, {}
    
    @staticmethod
    def extract_task_info(email: Dict, classification: Dict) -> Dict:
        """Extract task information from email"""
        subject = email.get('subject', '')
        sender = email.get('sender', '')
        snippet = email.get('snippet', '')
        thread_id = email.get('thread_id', '')
        email_id = email.get('id', '')
        
        # Generate title from subject or snippet
        title = subject if subject and subject != '' else snippet[:50]
        
        # Build description
        description = f"📧 From: {sender}\n"
        description += f"📌 Subject: {subject}\n\n"
        description += f"📝 Content: {snippet[:500]}\n"
        description += f"\n📎 Thread ID: {thread_id}"
        
        return {
            'title': title[:100],
            'description': description[:1000],
            'source': 'gmail',
            'source_id': email_id,
            'email_sender': sender,
            'email_subject': subject,
            'email_snippet': snippet[:200],
            'email_thread_id': thread_id,
            'priority': classification.get('suggested_priority', 'medium'),
            'category': 'email',
        }
    
    @staticmethod
    async def sync_emails(user_id: str, db, max_results: int = 50) -> Dict:
        """
        Full sync flow:
        1. Fetch emails from Gmail
        2. Classify each as actionable or not
        3. Create tasks for actionable emails
        """
        # Fetch emails
        emails = await GmailService.fetch_emails(user_id, db, max_results)
        
        if not emails:
            return {'synced': 0, 'tasks_created': 0, 'emails': []}
        
        tasks_created = 0
        actionable_emails = []
        
        for email in emails:
            email_id = email.get('id')
            
            # Skip if already processed
            existing = await db.gmail_emails.find_one({
                "user_id": ObjectId(user_id),
                "email_id": email_id
            })
            
            if existing:
                continue
            
            # Combine subject + body + snippet for analysis
            text_to_analyze = f"{email.get('subject', '')} {email.get('snippet', '')} {email.get('body', '')}"
            
            # 1. Check keywords first (free)
            is_actionable, classification = GmailService.is_actionable_keyword(text_to_analyze)
            
            # 2. If not found, check with AI (if available)
            if not is_actionable:
                is_actionable, classification = await GmailService.is_actionable_ai(text_to_analyze)
            
            # Store email in database regardless
            await db.gmail_emails.insert_one({
                "user_id": ObjectId(user_id),
                "email_id": email_id,
                "thread_id": email.get('thread_id'),
                "subject": email.get('subject', ''),
                "sender": email.get('sender', ''),
                "date": email.get('date', ''),
                "snippet": email.get('snippet', ''),
                "body": email.get('body', '')[:5000],
                "is_actionable": is_actionable,
                "is_task_created": False,
                "task_id": None,
                "classification": classification,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            })
            
            # Create task if actionable
            if is_actionable:
                task_info = GmailService.extract_task_info(email, classification)
                
                # Create task
                try:
                    task = TaskCreate(
                        title=task_info['title'],
                        description=task_info['description'],
                        priority=task_info['priority'],
                        category=task_info['category'],
                        source=task_info['source'],
                        source_id=task_info['source_id'],
                        email_sender=task_info.get('email_sender'),
                        email_subject=task_info.get('email_subject'),
                        email_snippet=task_info.get('email_snippet'),
                        email_thread_id=task_info.get('email_thread_id'),
                    )
                    
                    created_task = await create_task(task, user_id)
                    
                    # Update email with task reference
                    await db.gmail_emails.update_one(
                        {"user_id": ObjectId(user_id), "email_id": email_id},
                        {"$set": {
                            "is_task_created": True,
                            "task_id": str(created_task.id)
                        }}
                    )
                    
                    tasks_created += 1
                    actionable_emails.append({
                        'email_id': email_id,
                        'subject': email.get('subject'),
                        'task_id': str(created_task.id)
                    })
                    
                except Exception as e:
                    print(f"❌ Failed to create task from email {email_id}: {e}")
        
        return {
            'synced': len(emails),
            'tasks_created': tasks_created,
            'actionable_emails': actionable_emails
        }
    
    @staticmethod
    async def get_stored_emails(user_id: str, db, limit: int = 50) -> List[Dict]:
        """Get stored emails from database"""
        cursor = db.gmail_emails.find({
            "user_id": ObjectId(user_id)
        }).sort("created_at", -1).limit(limit)
        
        emails = await cursor.to_list(length=limit)
        return emails
    
    @staticmethod
    async def mark_as_read(user_id: str, db, email_id: str) -> bool:
        """Mark email as read in Gmail"""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            return False
        
        try:
            service.users().messages().modify(
                userId='me',
                id=email_id,
                body={'removeLabelIds': ['UNREAD']}
            ).execute()
            return True
        except Exception as e:
            print(f"❌ Error marking email as read: {e}")
            return False
    
    @staticmethod
    async def archive_email(user_id: str, db, email_id: str) -> bool:
        """Archive email in Gmail"""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            return False
        
        try:
            service.users().messages().modify(
                userId='me',
                id=email_id,
                body={'removeLabelIds': ['INBOX']}
            ).execute()
            return True
        except Exception as e:
            print(f"❌ Error archiving email: {e}")
            return False