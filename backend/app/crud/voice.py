# app/crud/voice.py

import whisper
import tempfile
import os
import asyncio
from functools import partial
from datetime import datetime, timezone
from app.db.connection import get_database

# ─────────────────────────────────────────────
# Whisper model — loaded once on server startup
# ─────────────────────────────────────────────
_model = None

async def load_whisper_model():
    """Load Whisper in a thread pool so server startup is not blocked"""
    global _model
    if _model is None:
        print("Loading Whisper base model... (one time only)")
        loop = asyncio.get_running_loop()
        _model = await loop.run_in_executor(None, partial(whisper.load_model, "base"))
        print("Whisper model loaded ✓")
    return _model


# ─────────────────────────────────────────────
# Transcription
# ─────────────────────────────────────────────
async def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    """
    Takes raw audio bytes → saves to temp file → runs Whisper → returns text.
    Runs in thread pool so FastAPI event loop is not blocked.
    """
    global _model
    if _model is None:
        await load_whisper_model()

    ext = os.path.splitext(filename)[-1] or ".m4a"

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(
            None,
            partial(_model.transcribe, tmp_path, fp16=False)
        )
        transcript = result["text"].strip()
        return transcript if transcript else "I couldn't understand that."
    finally:
        os.unlink(tmp_path)  # always delete temp file


# ─────────────────────────────────────────────
# MongoDB — save transcript to conversations
# ─────────────────────────────────────────────
async def save_voice_transcript(user_id: str, transcript: str) -> None:
    """
    Saves the transcribed text into the conversations collection.
    
    Two cases:
    1. User has no conversation document yet → create one with this message
    2. User already has a conversation document → append this message to messages array
    
    Each message has: role, content, source, timestamp
    """
    db = get_database()
    collection = db["conversations"]

    # Build the message object to save
    message = {
        "role": "user",          # this came from the user
        "content": transcript,   # the transcribed text
        "source": "voice",       # came from voice not typing
        "timestamp": datetime.now(timezone.utc)  # always use timezone-aware UTC
    }

    # upsert = update if exists, insert if not
    # $push appends to the messages array
    await collection.update_one(
        {"user_id": user_id},           # find document for this user
        {"$push": {"messages": message}},  # append new message
        upsert=True                     # create document if it doesn't exist
    )