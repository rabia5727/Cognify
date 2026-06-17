# app/routes/voice.py

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from app.crud.voice import transcribe_audio, save_voice_transcript
from app.models.voice import TranscriptionResponse
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/voice", tags=["Voice"])


@router.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_voice(
    audio: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)  # requires login
):
    """
    Receives audio from Flutter.
    1. Transcribes using Whisper
    2. Saves transcript to MongoDB conversations collection
    3. Returns transcript text

    Flutter sends:  multipart/form-data, field name = "audio"
    Returns:        { "transcript": "...", "source": "voice" }
    """

    if not audio:
        raise HTTPException(status_code=400, detail="No audio file received")

    audio_bytes = await audio.read()

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    # Step 1 — transcribe
    transcript = await transcribe_audio(audio_bytes, audio.filename or "audio.m4a")

    # Step 2 — save to MongoDB
    # current_user is the full user dict from DB — _id is the MongoDB ObjectId
    user_id = str(current_user["_id"])
    await save_voice_transcript(user_id, transcript)

    # Step 3 — return to Flutter
    return TranscriptionResponse(transcript=transcript, source="voice")