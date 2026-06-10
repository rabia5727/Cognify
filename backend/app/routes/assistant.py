# app/routes/assistant.py
# Two endpoints:
# POST /assistant/chat    → send message, get AI reply
# GET  /assistant/history → load full conversation for chat screen

from fastapi import APIRouter, HTTPException, Depends
from app.crud.assistant import chat_with_coco, get_full_history
from app.models.assistant import ChatRequest, ChatResponse, HistoryResponse, MessageOut
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/assistant", tags=["Assistant"])


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Main chat endpoint.
    
    Flutter sends: { "message": "what are my tasks?", "source": "text" }
    Returns:       { "reply": "You have 3 pending tasks...", "intent": "chat" }
    
    For voice input: Flutter first calls /voice/transcribe to get text,
    then calls this endpoint with source="voice" and the transcript as message.
    """
    user_id = str(current_user["_id"])

    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    # Call the orchestrator
    reply = await chat_with_coco(
        user_id=user_id,
        user_message=request.message,
        source=request.source       # "voice" or "text"
    )

    return ChatResponse(reply=reply, intent="chat")


@router.get("/history", response_model=HistoryResponse)
async def get_history(
    current_user: dict = Depends(get_current_user)
):
    """
    Returns full conversation history for this user.
    Flutter calls this when AssistantScreen opens.
    Renders each message as a chat bubble.
    """
    user_id = str(current_user["_id"])

    messages = await get_full_history(user_id)

    # Convert raw MongoDB dicts to MessageOut objects
    message_list = []
    for msg in messages:
        message_list.append(MessageOut(
            role=msg.get("role", "user"),
            content=msg.get("content", ""),
            source=msg.get("source", "text"),
            intent=msg.get("intent", "chat"),
            timestamp=msg.get("timestamp")
        ))

    return HistoryResponse(messages=message_list)