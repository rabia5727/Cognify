# app/crud/assistant.py
# Main AI Orchestrator — CoCo
# LangChain + Groq (Llama 3) + MongoDB conversation memory

from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from datetime import datetime, timezone
from app.db.connection import get_database
from app.config import settings


# ─────────────────────────────────────────────
# Initialize Groq LLM — loaded once on startup
# ─────────────────────────────────────────────
# ChatGroq connects to Groq's free API
# llama-3.3-70b-versatile is fast, free, and smart enough for our needs
llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.7,       # 0 = robotic/precise, 1 = creative. 0.7 is conversational
    max_tokens=512,        # keep replies concise — enough for task management
)

# ─────────────────────────────────────────────
# System prompt — defines CoCo's personality
# ─────────────────────────────────────────────
SYSTEM_PROMPT = """You are CoCo, an intelligent AI productivity assistant inside Cognify — 
an AI-powered execution hub for students and freelancers.

Your job is to help users manage their tasks, deadlines, projects, and productivity.
You are proactive, friendly, and concise. You understand academic and freelance workflows.

When users tell you about tasks, deadlines, or productivity concerns — acknowledge them 
and provide helpful, actionable guidance. Keep replies short and practical.

You are talking to a student or freelancer who is busy. Be direct and helpful.
Do not use markdown formatting in your replies — plain text only."""


# ─────────────────────────────────────────────
# Load conversation history from MongoDB
# ─────────────────────────────────────────────
async def get_conversation_history(user_id: str, limit: int = 10) -> list:
    """
    Loads the last N messages for this user from MongoDB.
    We only send the last 10 to Groq — sending all 500 messages would be slow and expensive.
    """
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id})

    if not doc or not doc.get("messages"):
        return []

    # Get last `limit` messages only — sliding window context
    messages = doc["messages"][-limit:]
    return messages


# ─────────────────────────────────────────────
# Save a message to MongoDB
# ─────────────────────────────────────────────
async def save_message(user_id: str, role: str, content: str, source: str = "text", intent: str = "chat") -> None:
    """
    Saves a single message to the conversations collection.
    Same $push pattern as voice — keeps everything in one array.
    """
    db = get_database()

    message = {
        "role": role,           # "user" or "assistant"
        "content": content,     # message text
        "source": source,       # "voice", "text", or "assistant"
        "intent": intent,       # detected intent
        "timestamp": datetime.now(timezone.utc)
    }

    await db["conversations"].update_one(
        {"user_id": user_id},
        {"$push": {"messages": message}},
        upsert=True             # create document if user has no conversation yet
    )


# ─────────────────────────────────────────────
# Main chat function — the Orchestrator
# ─────────────────────────────────────────────
async def chat_with_coco(user_id: str, user_message: str, source: str = "text") -> str:
    """
    Main orchestrator function.
    
    Flow:
    1. Load last 10 messages from MongoDB (conversation context)
    2. Build message list for Groq (system + history + new message)
    3. Send to Groq — get reply
    4. Save user message + AI reply to MongoDB
    5. Return AI reply to route
    """

    # Step 1 — Load conversation history
    history = await get_conversation_history(user_id, limit=10)

    # Step 2 — Build message list for LangChain
    # Always start with system prompt — defines CoCo's behavior
    langchain_messages = [SystemMessage(content=SYSTEM_PROMPT)]

    # Add conversation history so CoCo remembers context
    for msg in history:
        if msg["role"] == "user":
            langchain_messages.append(HumanMessage(content=msg["content"]))
        elif msg["role"] == "assistant":
            langchain_messages.append(AIMessage(content=msg["content"]))

    # Add the new user message
    langchain_messages.append(HumanMessage(content=user_message))

    # Step 3 — Send to Groq and get reply
    # ainvoke = async invoke — does not block the server
    response = await llm.ainvoke(langchain_messages)
    ai_reply = response.content.strip()

    # Step 4 — Save both messages to MongoDB
    # Save user message first
    await save_message(
        user_id=user_id,
        role="user",
        content=user_message,
        source=source,          # "voice" or "text" — passed from route
        intent="chat"           # Step 4 will detect real intent via tools
    )

    # Save AI reply
    await save_message(
        user_id=user_id,
        role="assistant",
        content=ai_reply,
        source="assistant",
        intent="chat"
    )

    # Step 5 — Return reply to route
    return ai_reply


# ─────────────────────────────────────────────
# Get full history for Flutter chat screen
# ─────────────────────────────────────────────
async def get_full_history(user_id: str) -> list:
    """
    Returns ALL messages for this user.
    Flutter calls this when the assistant screen opens
    to render the full conversation as chat bubbles.
    """
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id})

    if not doc or not doc.get("messages"):
        return []

    return doc["messages"]