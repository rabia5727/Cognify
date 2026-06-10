# app/models/assistant.py
# Data shapes for the AI assistant endpoints

from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional


class ChatRequest(BaseModel):
    """What Flutter sends to /assistant/chat"""
    message: str                    # the user's text message
    source: str = "text"            # "text" or "voice" — voice route sets this to "voice"


class ChatResponse(BaseModel):
    """What /assistant/chat returns to Flutter"""
    reply: str                      # AI's response text
    intent: str = "chat"            # detected intent — "chat" for now, tool name in Step 4


class MessageOut(BaseModel):
    """A single message for the history endpoint"""
    role: str                       # "user" or "assistant"
    content: str                    # message text
    source: str = "text"            # "voice", "text", or "assistant"
    intent: str = "chat"            # intent detected
    timestamp: Optional[datetime]   # when it was sent


class HistoryResponse(BaseModel):
    """What /assistant/history returns"""
    messages: List[MessageOut]