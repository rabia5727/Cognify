# app/crud/voice.py
#
# Migrated from local Whisper → Groq hosted STT + TTS
# STT: whisper-large-v3-turbo (Groq)
# TTS: playai-tts (Groq)
# Uses same dual-key fallback pattern as your other agents.

import os
import tempfile
import httpx
from datetime import datetime, timezone
from app.db.connection import get_database

# ─────────────────────────────────────────────
# Groq API keys — same dual-key fallback pattern
# you already use in your agents
# ─────────────────────────────────────────────
_GROQ_KEYS = [
    os.getenv("GROQ_API_KEY"),
    os.getenv("GROQ_API_KEY_2"),
]

def _get_groq_headers(key: str) -> dict:
    return {
        "Authorization": f"Bearer {key}",
    }


async def _try_groq_stt(audio_bytes: bytes, filename: str) -> str:
    """
    Tries each Groq key in order.
    Groq STT endpoint accepts multipart/form-data with the audio file.
    Returns the transcribed text.
    """
    url = "https://api.groq.com/openai/v1/audio/transcriptions"

    last_error = None

    for key in _GROQ_KEYS:
        if not key:
            continue  # skip if key is not set in .env

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.post(
                    url,
                    headers=_get_groq_headers(key),
                    files={
                        # "file" is what Groq expects — filename matters for
                        # format detection so pass it through from Flutter
                        "file": (filename, audio_bytes, "audio/m4a"),
                    },
                    data={
                        "model": "whisper-large-v3-turbo",
                        "response_format": "json",
                        "language": "en",   # remove this line if you want
                    },                       # auto language detection
                )

                if response.status_code == 200:
                    result = response.json()
                    text = result.get("text", "").strip()
                    return text if text else "I couldn't understand that."

                # 429 = rate limit → try next key
                if response.status_code == 429:
                    last_error = f"Key rate limited: {key[:8]}..."
                    continue

                # Any other error — raise immediately, not a key issue
                raise Exception(
                    f"Groq STT error {response.status_code}: {response.text}"
                )

        except httpx.TimeoutException:
            last_error = "Groq STT request timed out"
            continue

    raise Exception(f"All Groq keys failed for STT. Last error: {last_error}")


async def _try_groq_tts(text: str) -> bytes:
    """
    Tries each Groq key in order.
    Groq TTS endpoint returns raw audio bytes (wav).
    Returns the audio bytes to send back to Flutter.
    """
    url = "https://api.groq.com/openai/v1/audio/speech"

    last_error = None

    for key in _GROQ_KEYS:
        if not key:
            continue

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.post(
                    url,
                    headers={
                        **_get_groq_headers(key),
                        "Content-Type": "application/json",
                    },
                    json={
                       "model": "canopylabs/orpheus-v1-english",
                        "input": text,
                        "voice": "diana",  # natural female voice
                        "response_format": "wav",   # Flutter plays wav easily
                    },
                )

                if response.status_code == 200:
                    return response.content  # raw audio bytes

                if response.status_code == 429:
                    last_error = f"Key rate limited: {key[:8]}..."
                    continue

                raise Exception(
                    f"Groq TTS error {response.status_code}: {response.text}"
                )

        except httpx.TimeoutException:
            last_error = "Groq TTS request timed out"
            continue

    raise Exception(f"All Groq keys failed for TTS. Last error: {last_error}")


# ─────────────────────────────────────────────
# Public functions — called by routes/voice.py
# ─────────────────────────────────────────────

async def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    """
    Sends audio to Groq whisper-large-v3-turbo.
    Returns transcribed text string.
    No local model, no ffmpeg, no RAM usage on your laptop.
    """
    return await _try_groq_stt(audio_bytes, filename)


async def synthesize_speech(text: str) -> bytes:
    """
    Sends text to Groq playai-tts.
    Returns WAV audio bytes to stream back to Flutter.
    """
    return await _try_groq_tts(text)


# ─────────────────────────────────────────────
# MongoDB — save transcript to conversations
# ─────────────────────────────────────────────

async def save_voice_transcript(user_id: str, transcript: str) -> None:
    """
    Saves the transcribed text into the conversations collection.
    Unchanged from your original — same schema, same upsert pattern.
    """
    db = get_database()
    collection = db["conversations"]

    message = {
        "role": "user",
        "content": transcript,
        "source": "voice",
        "timestamp": datetime.now(timezone.utc),
    }

    await collection.update_one(
        {"user_id": user_id},
        {"$push": {"messages": message}},
        upsert=True,
    )