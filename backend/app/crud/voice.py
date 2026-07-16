import tempfile
import os
import asyncio
from functools import partial
from datetime import datetime, timezone
from faster_whisper import WhisperModel  # <-- Changed import
from app.db.connection import get_database

# ─────────────────────────────────────────────
# Whisper model — loaded once on server startup
# ─────────────────────────────────────────────
_model = None

async def load_whisper_model():
    """Load Whisper in a thread pool so server startup is not blocked"""
    global _model
    if _model is None:
        print("Loading Faster-Whisper base model... (one time only)")
        loop = asyncio.get_running_loop()
        # Runs on CPU by default (int8 quantization is very fast and lightweight)
        _model = await loop.run_in_executor(
            None, 
            lambda: WhisperModel("base", device="cpu", compute_type="int8")
        )
        print("Faster-Whisper model loaded ✓")
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
        
        # faster-whisper's transcribe method returns a generator of segments
        def run_transcription():
            segments, info = _model.transcribe(tmp_path, beam_size=5)
            # Joins all segments into a single string
            return "".join([segment.text for segment in segments])

        transcript = await loop.run_in_executor(None, run_transcription)
        transcript = transcript.strip()
        
        return transcript if transcript else "I couldn't understand that."
    finally:
        os.unlink(tmp_path)  # always delete temp file


# ─────────────────────────────────────────────
# MongoDB — save transcript to conversations
# ─────────────────────────────────────────────
async def save_voice_transcript(user_id: str, transcript: str) -> None:
    db = get_database()
    collection = db["conversations"]

    message = {
        "role": "user",
        "content": transcript,
        "source": "voice",
        "timestamp": datetime.now(timezone.utc)
    }

    await collection.update_one(
        {"user_id": user_id},
        {"$push": {"messages": message}},
        upsert=True
    )