# app/routes/assistant.py
#
# ✅ SESSION REWRITE — endpoints now support multiple separate chats:
#   POST   /assistant/chat              → send message (session-aware)
#   GET    /assistant/history           → load ONE session's messages
#   GET    /assistant/sessions          → list all chat sessions (sidebar)
#   POST   /assistant/sessions          → start a new empty chat
#   DELETE /assistant/sessions/{id}     → delete a chat session
#   POST   /assistant/briefing          → unchanged, manual briefing trigger

from fastapi import APIRouter, HTTPException, Depends, Query
from app.crud.assistant import (
    chat_with_coco,
    get_session_history,
    list_user_sessions,
    create_new_session,
    delete_session,
    trigger_manual_briefing,
)
from app.models.assistant import (
    ChatRequest, ChatResponse, HistoryResponse, MessageOut,
    SessionListResponse, SessionSummary, NewSessionResponse,
)
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/assistant", tags=["Assistant"])


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Main chat endpoint — now session-aware.

    Flutter sends: { "message": "...", "source": "text", "session_id": "abc-123" }
    If session_id is omitted/empty, a NEW chat session is created
    automatically and its id is returned in the response — Flutter
    should store this id and pass it on subsequent messages in the
    same chat.
    """
    user_id = str(current_user["_id"])

    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    result = await chat_with_coco(
        user_id=user_id,
        user_message=request.message,
        source=request.source,
        session_id=request.session_id,
    )

    return ChatResponse(
        reply=result["reply"],
        intent=result["intent"],
        session_id=result["session_id"],
    )


@router.get("/history", response_model=HistoryResponse)
async def get_history(
    session_id: str = Query(..., description="Which chat session to load"),
    current_user: dict = Depends(get_current_user)
):
    """
    Returns conversation history for ONE specific chat session.

    ✅ CHANGED: session_id is now REQUIRED — Flutter must specify which
    chat to load. Previously this returned ALL of a user's messages
    merged together; now each chat is isolated.
    """
    user_id = str(current_user["_id"])

    data = await get_session_history(user_id, session_id)

    message_list = [
        MessageOut(
            role=msg.get("role", "user"),
            content=msg.get("content", ""),
            source=msg.get("source", "text"),
            intent=msg.get("intent", "chat"),
            timestamp=msg.get("timestamp"),
        )
        for msg in data["messages"]
    ]

    return HistoryResponse(
        messages=message_list,
        session_id=data["session_id"],
        title=data["title"],
    )


@router.get("/sessions", response_model=SessionListResponse)
async def get_sessions(
    current_user: dict = Depends(get_current_user)
):
    """
    ✅ NEW: Returns all of the user's chat sessions, newest first.
    This powers the sidebar/drawer showing separate chats — the core
    fix for "history should show in separate chats, not one single chat".
    """
    user_id = str(current_user["_id"])
    sessions = await list_user_sessions(user_id)

    return SessionListResponse(
        sessions=[SessionSummary(**s) for s in sessions]
    )


@router.post("/sessions", response_model=NewSessionResponse)
async def new_session(
    current_user: dict = Depends(get_current_user)
):
    """
    ✅ NEW: Starts a brand new, empty chat session.
    Flutter calls this when the user taps "+ New Chat".
    """
    user_id = str(current_user["_id"])
    result = await create_new_session(user_id)
    return NewSessionResponse(**result)


@router.delete("/sessions/{session_id}")
async def remove_session(
    session_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    ✅ NEW: Deletes a chat session permanently.
    """
    user_id = str(current_user["_id"])
    deleted = await delete_session(user_id, session_id)

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail=f"Session {session_id} not found or doesn't belong to you"
        )

    return {"message": "Session deleted successfully"}


@router.post("/briefing")
async def trigger_briefing(current_user: dict = Depends(get_current_user)):
    """
    Manually trigger a morning briefing for the current user.
    Unchanged — still uses its own logic in proactive_agent.py.
    """
    user_id = str(current_user["_id"])
    briefing = await trigger_manual_briefing(user_id)
    return {"briefing": briefing, "message": "Briefing generated and saved"}