# app/models/assistant.py
# Data shapes for the AI assistant endpoints
#
# ✅ NEW: Added session-based chat support.
# Previously: one conversation document per user, flat messages array
# forever. Now: each chat is its own session with a session_id, title,
# and its own messages — matching ChatGPT-style separate chat threads.

from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional


class ChatRequest(BaseModel):
    """What Flutter sends to /assistant/chat"""
    message: str                    # the user's text message
    source: str = "text"            # "text" or "voice"
    # ✅ NEW: which chat session this message belongs to.
    # If omitted/empty, backend creates a new session automatically
    # (handles the very first message of a brand new chat).
    session_id: str = ""


class ChatResponse(BaseModel):
    """What /assistant/chat returns to Flutter"""
    reply: str                      # AI's response text
    intent: str = "chat"            # detected intent — tool name or "chat"
    # ✅ NEW: echoes back which session this reply belongs to, so Flutter
    # can store it (important for the very first message, where the
    # backend generates a brand new session_id).
    session_id: str = ""


class MessageOut(BaseModel):
    """A single message for the history endpoint"""
    role: str                       # "user" or "assistant"
    content: str                    # message text
    source: str = "text"            # "voice", "text", or "assistant"
    intent: str = "chat"            # intent detected
    timestamp: Optional[datetime]   # when it was sent


class HistoryResponse(BaseModel):
    """What /assistant/history returns — messages for ONE session"""
    messages: List[MessageOut]
    session_id: str = ""
    title: str = ""


# ✅ NEW: Lightweight summary of one chat session, for the sidebar list.
# Deliberately excludes full messages — listing all sessions should be
# fast and not pull every message of every chat.
class SessionSummary(BaseModel):
    session_id: str
    title: str
    last_message_preview: str = ""   # short snippet for sidebar subtitle
    message_count: int = 0
    created_at: Optional[datetime]
    updated_at: Optional[datetime]


class SessionListResponse(BaseModel):
    """What GET /assistant/sessions returns — for the chat sidebar"""
    sessions: List[SessionSummary]


class NewSessionResponse(BaseModel):
    """What POST /assistant/sessions returns when starting a new chat"""
    session_id: str
    title: str