# app/routes/voice.py
#
# Two endpoints:
# POST /voice/transcribe  — audio → text (STT)
# POST /voice/synthesize  — text → audio (TTS)

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import Response
from pydantic import BaseModel
from app.crud.voice import transcribe_audio, synthesize_speech, save_voice_transcript
from app.models.voice import TranscriptionResponse
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/voice", tags=["Voice"])


# ─────────────────────────────────────────────
# STT — Flutter sends audio, gets back text
# ─────────────────────────────────────────────

@router.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_voice(
    audio: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    """
    Receives audio from Flutter → transcribes via Groq whisper-large-v3-turbo
    → saves to MongoDB → returns transcript text.

    Flutter sends:  multipart/form-data, field name = "audio"
    Returns:        { "transcript": "...", "source": "voice" }
    """
    if not audio:
        raise HTTPException(status_code=400, detail="No audio file received")

    audio_bytes = await audio.read()

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    try:
        transcript = await transcribe_audio(
            audio_bytes,
            audio.filename or "audio.m4a",
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Transcription failed: {str(e)}")

    # Save to MongoDB — same as before
    user_id = str(current_user["_id"])
    await save_voice_transcript(user_id, transcript)

    return TranscriptionResponse(transcript=transcript, source="voice")


# ─────────────────────────────────────────────
# TTS — Flutter sends text, gets back audio
# ─────────────────────────────────────────────

class SynthesizeRequest(BaseModel):
    text: str


@router.post("/synthesize")
async def synthesize_voice(
    body: SynthesizeRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Receives text from Flutter → synthesizes via Groq playai-tts
    → streams WAV audio bytes back.

    Flutter receives: audio/wav bytes — play with just_audio or audioplayers.
    """
    if not body.text or not body.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    # Groq TTS has a ~4000 char limit — truncate gracefully for safety
    text = body.text.strip()[:3900]

    try:
        audio_bytes = await synthesize_speech(text)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Speech synthesis failed: {str(e)}")

    # Return raw WAV bytes — Flutter reads this directly
    return Response(
        content=audio_bytes,
        media_type="audio/wav",
    )