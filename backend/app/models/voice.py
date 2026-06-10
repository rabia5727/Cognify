# app/models/voice.py

from pydantic import BaseModel
from datetime import datetime
from typing import List


class TranscriptionResponse(BaseModel):
    """What the API returns after transcribing audio"""
    transcript: str         # the text whisper extracted from audio
    source: str = "voice"   # always "voice"


class ConversationMessage(BaseModel):
    """A single message in a conversation — user or assistant"""
    role: str               # "user" or "assistant"
    content: str            # the actual text
    source: str = "text"    # "voice" or "text"
    timestamp: datetime = datetime.utcnow()


class ConversationInDB(BaseModel):
    """What gets stored in MongoDB conversations collection"""
    user_id: str
    messages: List[ConversationMessage] = []