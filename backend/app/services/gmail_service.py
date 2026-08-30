# Purpose: Gmail API integration - fetch, classify, and store emails
# Methods:
#   - get_gmail_service() - Build authenticated Gmail API client
#   - fetch_emails() - Get recent emails from Gmail API
#   - is_actionable_keyword() - Free keyword/regex check
#   - is_actionable_ai() - AI API fallback check
#   - extract_task_info() - Pull title/date/sender/snippet/thread_id
#   - sync_emails() - Full sync flow: fetch → classify → create tasks
#
# IMPORTANT: googleapiclient is synchronous — every .execute() call blocks
# the whole FastAPI event loop for its duration if called directly inside
# an async def (verified: a single sync stalled an unrelated request for
# ~10s). All calls here go through asyncio.to_thread(); per-message fetches
# in fetch_emails() also run concurrently via asyncio.gather instead of a
# sequential loop.
import asyncio
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
    
    # ✅ Actionable keywords - more specific
    ACTION_KEYWORDS = [
         # Work/Professional
    r'project\s+(?:deadline|due|update|submission|review)',
    r'report\s+(?:due|needed|required|for|submission)',
    r'assignment\s+(?:due|submission|deadline)',
    r'task\s+(?:assigned|created|updated|for|due|complete)',
    r'deliverable',
    r'milestone',
    r'sprint',
    
    # Meeting/Communication
    r'meeting\s+(?:at|with|tomorrow|today|schedule|agenda)',
    # NOTE: a "call with/at/schedule" pattern used to live here, but
    # generic phrases like "schedule a call with us" are just as common
    # in marketing copy as real requests — removed as a hard keyword
    # match; the AI fallback (is_actionable_ai) handles "let's have a
    # call" style requests correctly with actual context, which regex
    # can't distinguish from a sales pitch.
    r'follow[- ]?up',

    # Actions/Requests
    r'action\s*required',
    r'please\s*(?:review|approve|confirm|send|complete|respond|submit)',
    r'need\s+your\s+(?:input|feedback|approval|response|review)',
    r'can\s+you\s+(?:send|review|confirm|approve|submit|check)',
    r'could\s+you\s+please',
    r'waiting\s+for\s+your',
    r'feedback\s+needed',
    r'approval\s+needed',
    r'response\s+needed',

    # Deadlines — bare "reminder"/"due"/"urgent"/"asap" removed: they're
    # just as common in personal mail ("reminder: dentist appointment",
    # "rent due", "urgent: family matter") as work mail, so on their own
    # they let non-work email through. "deadline" alone stays since it's
    # overwhelmingly a work/academic word.
    r'deadline',
    r'by\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|tomorrow|\d{1,2}/\d{1,2})',

    # Documents/Submissions
    r'invoice',
    # Requires a real work object after "submit your/the" — the previous
    # version (`submit\s+(?:your|the|report|assignment|project)`) treated
    # "your"/"the" alone as satisfying the whole pattern, so "submit your
    # build [for a hackathon]" matched a promo email just as well as
    # "submit your report" matched a real one.
    r'submit\s+(?:your|the)\s+(?:report|assignment|project|proposal|work|homework|paper|form)',
    r'attached\s+is\s+the',
    r'please\s+find\s+attached',
    r'file\s+upload',
    r'proposal',
    r'budget',
    r'contract',
    r'agreement',
    ]
    
    # ❌ Ignore patterns (system/welcome/newsletter/spam)
    IGNORE_PATTERNS = [
        # System/welcome emails
        r'welcome\s+to',
        r'welcome,',
        r'get\s+started',
        r'your\s+automation\s+forecast',
        r'welcome\s+aboard',
        r'thank\s+you\s+for\s+(?:signing|joining|subscribing)',
        r'verify\s+your\s+email',
        r'confirm\s+your\s+account',
        r'complete\s+your\s+profile',
        r'you\'re\s+all\s+set',
        
        # Newsletters & promotions
        r'newsletter',
        r'marketing',
        r'promotion',
        r'unsubscribe',
        r'you\s*received\s*a\s*message',
        r'donotreply',
        r'noreply',
        r'special\s+offer',
        r'discount',
        r'sale\s+now',
        r'limited\s+time',
        
        # Auto-replies
        r'automated\s+response',
        r'automatic\s+reply',
        r'out\s+of\s+office',
        r'out\s+of\s+the\s+office',
        r'vacation\s+auto[- ]?reply',
    ]
    
    # ❌ Ignore senders (system emails)
    IGNORE_SENDERS = [
       # Welcome/Onboarding
    r'welcome\s+to',
    r'welcome,',
    r'get\s+started',
    r'your\s+automation\s+forecast',
    r'welcome\s+aboard',
    r'thank\s+you\s+for\s+(?:signing|joining|subscribing)',
    r'verify\s+your\s+email',
    r'confirm\s+your\s+account',
    r'complete\s+your\s+profile',
    r"you're\s+all\s+set",
    
    # Newsletters & Promotions
    r'newsletter',
    r'marketing',
    r'promotion',
    r'unsubscribe',
    r'special\s+offer',
    r'discount',
    r'sale\s+now',
    r'limited\s+time',
    r'credit\s+purchases',  # Add this to block "credit purchase" emails
    r'crypto',
    r'investment\s+opportunity',
    
    # System/Auto
    r'donotreply',
    r'noreply',
    r'automated\s+response',
    r'automatic\s+reply',
    r'out\s+of\s+office',
    r'out\s+of\s+the\s+office',
    r'vacation\s+auto[- ]?reply',
    r'you\s*received\s*a\s*message',
    
    # Social/Entertainment
    r'social\s+media',
    r'instagram',
    r'facebook',
    r'twitter',
    r'linkedin',
    r'medium\.com',
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
        # Tokens minted via "Connect All" were issued under CONNECT_ALL_CLIENT_ID,
        # not GMAIL_CLIENT_ID — refreshing under the wrong client gets
        # rejected by Google with "unauthorized_client".
        if tokens.get('oauth_client') == 'connect_all':
            client_id = settings.CONNECT_ALL_CLIENT_ID
            client_secret = settings.CONNECT_ALL_CLIENT_SECRET
        else:
            client_id = GmailService._client_id()
            client_secret = GmailService._client_secret()

        creds = Credentials(
            token=tokens.get('access_token'),
            refresh_token=tokens.get('refresh_token'),
            token_uri='https://oauth2.googleapis.com/token',
            client_id=client_id,
            client_secret=client_secret,
            scopes=GmailService.SCOPES,
            expiry=tokens.get('expires_at'),
        )

        if creds.expired and creds.refresh_token:
            await asyncio.to_thread(creds.refresh, Request())
            # creds.expiry is already a naive UTC datetime — store it
            # directly. Round-tripping through .timestamp() treats it as
            # local time and shifts it by the server's UTC offset.
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {
                    "gmail_tokens.access_token": creds.token,
                    "gmail_tokens.expires_at": creds.expiry,
                }}
            )

        return await asyncio.to_thread(build, 'gmail', 'v1', credentials=creds)
    
    @staticmethod
    async def fetch_emails(user_id: str, db, max_results: int = 50) -> List[Dict]:
        """Fetch recent emails from Gmail API"""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            return []
        
        try:
            # Get messages from inbox (excluding spam)
            results = await asyncio.to_thread(
                service.users().messages().list(
                    userId='me',
                    maxResults=max_results,
                    q='in:inbox -in:spam -in:trash'
                ).execute
            )

            messages = results.get('messages', [])
            if not messages:
                return []

            # Sequential, not parallel: this `service` object's underlying
            # httplib2 transport isn't safe for concurrent use across
            # threads (running these via asyncio.gather deadlocked the
            # whole request). Each call still goes through asyncio.to_thread
            # though, so it doesn't block the event loop the way a direct
            # .execute() would — other requests keep being served while
            # this runs, it just doesn't run its own steps in parallel.
            emails = []
            for msg in messages:
                try:
                    email_data = await asyncio.to_thread(
                        service.users().messages().get(
                            userId='me', id=msg['id'], format='full'
                        ).execute
                    )
                    emails.append(GmailService._parse_email(email_data))
                except Exception as e:
                    print(f"Failed to fetch message {msg['id']}: {e}")
                    continue

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
    def is_ignored(text: str, sender: str = "") -> bool:
        """
        True if the sender/content matches a known junk pattern (system
        mail, newsletters, auto-replies). Shared by the keyword check and
        the AI fallback, so the AI classifier never spends a call — or
        risks misreading a sale as a "deadline" — on obvious junk mail.
        """
        text_lower = text.lower()

        for ignore_sender in GmailService.IGNORE_SENDERS:
            if re.search(ignore_sender, sender.lower()):
                return True

        for pattern in GmailService.IGNORE_PATTERNS:
            if re.search(pattern, text_lower):
                return True

        return False

    @staticmethod
    def is_actionable_keyword(text: str, sender: str = "") -> Tuple[bool, Dict]:
        """
        Check if email is actionable using keyword matching.
        Returns: (is_actionable, extracted_info)
        """
        text_lower = text.lower()

        if GmailService.is_ignored(text, sender):
            return False, {}

        # ✅ Check actionable keywords
        matched_keywords = []
        for pattern in GmailService.ACTION_KEYWORDS:
            if re.search(pattern, text_lower):
                matched_keywords.append(pattern)
        
        if not matched_keywords:
            return False, {}
        
        print(f"✅ Actionable email: matched keywords: {matched_keywords}")
        
        # Extract potential due date
        due_date = None
        date_patterns = [
            r'by\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|tomorrow)',
            r'by\s*(\d{1,2}/\d{1,2})',
            r'due\s*(\d{1,2}/\d{1,2})',
            r'on\s*(\d{1,2}/\d{1,2})',
        ]
        for pattern in date_patterns:
            match = re.search(pattern, text_lower)
            if match:
                due_date = match.group(1) if len(match.groups()) > 0 else 'soon'
                break
        
        # Determine priority
        priority = 'medium'
        high_priority_words = ['urgent', 'asap', 'deadline', 'immediately', 'critical']
        if any(k in ' '.join(matched_keywords) for k in high_priority_words):
            priority = 'high'
        
        return True, {
            'matched_keywords': matched_keywords,
            'suggested_due_date': due_date,
            'suggested_priority': priority
        }
    
    @staticmethod
    async def is_actionable_ai(text: str) -> Tuple[bool, Dict]:
        """
        AI fallback classifier — only called when keyword matching finds
        nothing. Regex patterns miss natural phrasing (e.g. "need the
        report till 10am" doesn't contain "report due"/"by <day>"/any
        recognized deadline word), so this catches what the fixed keyword
        list can't anticipate, without replacing it as the primary (free,
        fast) check.
        """
        try:
            from langchain_groq import ChatGroq
            from langchain_core.messages import HumanMessage
            from app.config import settings

            # Uses the stronger orchestrator model, not the lightweight one:
            # this fallback only runs on the small subset of emails keyword
            # matching didn't already resolve, so the volume is low but the
            # judgment call (work/academic vs. personal, not just
            # "actionable") needs real reasoning — the lightweight model
            # mis-flagged "URGENT: family emergency, call me back" and
            # "subscription payment due" as actionable in testing.
            llm = ChatGroq(
                api_key=settings.GROQ_API_KEY,
                model=settings.ORCHESTRATOR_MODEL,
                temperature=0,
                max_tokens=60,
                timeout=15,
                max_retries=1,
            )
            prompt = (
                "Is this email WORK or ACADEMIC related, AND does it "
                "require the recipient to DO something — a task, "
                "deadline, submission, or request from a colleague, "
                "manager, client, professor, or classmate? Both must be "
                "true to count as actionable.\n\n"
                "Say NOT actionable for: personal/family/social email "
                "(even if it asks you to do something — a personal "
                "reminder, appointment, or favor is not work/academic), "
                "FYIs, notifications, newsletters, receipts, promotions, "
                "or automated alerts.\n\n"
                "Reply with ONLY these two lines, nothing else:\n"
                "ACTIONABLE: yes or no\n"
                "PRIORITY: high, medium, or low\n\n"
                f"Email:\n{text[:800]}"
            )
            response = await llm.ainvoke([HumanMessage(content=prompt)])
            raw = (response.content or "").lower()

            if "actionable: yes" not in raw:
                return False, {}

            priority = "medium"
            if "priority: high" in raw:
                priority = "high"
            elif "priority: low" in raw:
                priority = "low"

            return True, {
                "matched_keywords": ["ai_classified"],
                "suggested_due_date": None,
                "suggested_priority": priority,
            }

        except Exception as e:
            print(f"AI check failed: {e}")
            return False, {}
    
    @staticmethod
    def extract_task_info(email: Dict, classification: Dict) -> Dict:
        """Extract task information from email"""
        subject = email.get('subject', '')
        sender = email.get('sender', '')
        snippet = email.get('snippet', '')
        thread_id = email.get('thread_id', '')
        email_id = email.get('id', '')
        
        # Generate title from subject (clean up)
        title = subject if subject and subject != '' else snippet[:50]
        # Remove common prefixes
        title = re.sub(r'^(?:Fwd:|Re:|RE:|FW:)', '', title).strip()
        
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
            
            # Get email data
            subject = email.get('subject', '')
            sender = email.get('sender', '')
            snippet = email.get('snippet', '')
            body = email.get('body', '')
            
            # ✅ Check subject FIRST (highest weight)
            subject_actionable, subject_classification = GmailService.is_actionable_keyword(
                subject, sender
            )
            
            if subject_actionable:
                is_actionable = True
                classification = subject_classification
                print(f"📌 Actionable from subject: '{subject}'")
            else:
                # ✅ Then check full email
                text_to_analyze = f"{subject} {snippet} {body[:1000]}"
                is_actionable, classification = GmailService.is_actionable_keyword(
                    text_to_analyze, sender
                )

                # Keyword lists can't anticipate every phrasing (e.g. "need
                # the report till 10am" has no recognized deadline word) —
                # fall back to the AI classifier, but only for mail that
                # isn't already known junk (is_ignored), so it's not
                # wasted on newsletters/system mail.
                if not is_actionable and not GmailService.is_ignored(text_to_analyze, sender):
                    is_actionable, classification = await GmailService.is_actionable_ai(
                        text_to_analyze
                    )
                    if is_actionable:
                        print(f"AI classified as actionable: '{subject}'")

            # Store email in database regardless
            await db.gmail_emails.insert_one({
                "user_id": ObjectId(user_id),
                "email_id": email_id,
                "thread_id": email.get('thread_id'),
                "subject": subject,
                "sender": sender,
                "date": email.get('date', ''),
                "snippet": snippet,
                "body": body[:5000],
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
                        'subject': subject,
                        'task_id': str(created_task.id)
                    })
                    print(f"✅ Created task from email: '{subject}'")
                    
                except Exception as e:
                    print(f"❌ Failed to create task from email {email_id}: {e}")
        
        print(f"📊 Sync complete: {len(emails)} emails, {tasks_created} tasks created")
        return {
            'synced': len(emails),
            'tasks_created': tasks_created,
            'actionable_emails': actionable_emails
        }
    
    @staticmethod
    async def get_stored_emails(
        user_id: str, db, limit: int = 50, actionable_only: bool = True
    ) -> List[Dict]:
        """
        Get stored emails from database. Every fetched email gets stored
        (that's what makes the sync's dedup check work — re-fetching the
        same 50 inbox emails every sync shouldn't re-run classification on
        each one), but actionable_only=True means what the user actually
        sees is scoped to work/academic mail, not the raw inbox.
        """
        query = {"user_id": ObjectId(user_id)}
        if actionable_only:
            query["is_actionable"] = True

        cursor = db.gmail_emails.find(query).sort("created_at", -1).limit(limit)

        emails = await cursor.to_list(length=limit)
        return emails
    
    @staticmethod
    async def mark_as_read(user_id: str, db, email_id: str) -> bool:
        """Mark email as read in Gmail"""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            return False
        
        try:
            await asyncio.to_thread(
                service.users().messages().modify(
                    userId='me',
                    id=email_id,
                    body={'removeLabelIds': ['UNREAD']}
                ).execute
            )
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
            await asyncio.to_thread(
                service.users().messages().modify(
                    userId='me',
                    id=email_id,
                    body={'removeLabelIds': ['INBOX']}
                ).execute
            )
            return True
        except Exception as e:
            print(f"❌ Error archiving email: {e}")
            return False

    @staticmethod
    async def send_email(user_id: str, db, to: str, subject: str, body: str) -> dict:
        """Send an email via the Gmail API from the user's connected account.
        gmail.modify (already in SCOPES) covers messages.send — no extra
        scope or re-consent needed."""
        service = await GmailService.get_gmail_service(user_id, db)
        if not service:
            raise Exception("Gmail not connected")

        from email.mime.text import MIMEText

        message = MIMEText(body)
        message['to'] = to
        message['subject'] = subject

        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()

        sent = await asyncio.to_thread(
            service.users().messages().send(
                userId='me',
                body={'raw': raw}
            ).execute
        )
        return {'message_id': sent.get('id'), 'thread_id': sent.get('threadId')}