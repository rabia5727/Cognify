# app/crud/assistant.py
# CoCo — Main AI Orchestrator
# Uses LangChain bind_tools pattern for reliable tool calling with Groq
#
# ✅ SESSION REWRITE:
# Previously: ONE conversation document per user_id, with a single
# "messages" array that grew forever via $push. This meant every chat
# the user ever had was visually merged into ONE continuous thread —
# the root cause of the "history shows in one single chat" bug.
#
# Now: each chat is its OWN document in the "conversations" collection,
# keyed by a unique session_id. A user can have many conversation
# documents, each with its own title + messages array. This matches
# ChatGPT-style separate, switchable chat sessions.

import uuid
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, ToolMessage
from datetime import datetime, timezone
from app.db.connection import get_database
from app.config import settings

from app.agents.task_agent import get_task_agent_tools
from app.agents.execution_agent import get_execution_agent_tools
from app.agents.scheduler_agent import get_scheduler_agent_tools
from app.agents.analytics_agent import get_analytics_agent_tools

# ─────────────────────────────────────────────────────────────────
# LLM
# ─────────────────────────────────────────────────────────────────
_base_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.7,
    max_tokens=1024,
)

SYSTEM_PROMPT = """You are CoCo, an intelligent AI productivity assistant inside Cognify.
You help students and freelancers manage tasks, deadlines, projects, and productivity.

You have tools available. Use them whenever appropriate:
- create_task_tool: when user wants to add/create/schedule a task
- get_user_tasks: when user asks to see/list/show their tasks
- check_deadlines: when user asks about due dates or urgent tasks
- update_task_status: when user wants to mark a task done/complete
- get_user_projects: when user asks about their projects
- breakdown_task: when user needs help with a complex task
- build_study_plan: when user has academic work to prepare for
- create_subtasks: when breaking a task into smaller pieces
- suggest_resources: when user needs learning help
- summarize_day: when user asks about their day overview
- prioritize_tasks: when user asks what to work on first
- check_workload_balance: when user asks if they are overloaded
- find_free_slots: when user asks when they can work
- get_productivity_score: when user asks about productivity stats
- get_weekly_summary: when user asks about their week
- get_most_active_hour: when user asks their peak productive time

ALWAYS use a tool when the user's request matches one above.
Keep replies concise, friendly, and in plain text."""


# ─────────────────────────────────────────────────────────────────
# ✅ NEW: Session helpers
# ─────────────────────────────────────────────────────────────────

def _generate_title_from_message(message: str) -> str:
    """
    Auto-generates a short chat title from the first user message,
    same pattern ChatGPT uses. Truncates to keep sidebar tidy.
    """
    cleaned = message.strip().replace("\n", " ")
    if len(cleaned) <= 40:
        return cleaned
    return cleaned[:40].rsplit(" ", 1)[0] + "..."


async def create_new_session(user_id: str, first_message: str = "") -> dict:
    """
    Creates a brand new, empty conversation document.
    Called when:
      - user explicitly taps "New Chat"
      - OR the very first message arrives with no session_id (auto-create)
    """
    db = get_database()
    session_id = str(uuid.uuid4())
    title = _generate_title_from_message(first_message) if first_message else "New Chat"

    doc = {
        "session_id": session_id,
        "user_id": user_id,
        "title": title,
        "messages": [],
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    await db["conversations"].insert_one(doc)
    return {"session_id": session_id, "title": title}


async def get_conversation_history(user_id: str, session_id: str, limit: int = 8) -> list:
    """
    Loads recent messages for ONE session (not all of the user's chats)
    to feed into the LLM as context. This is what was previously
    pulling from the single shared document — now scoped correctly.
    """
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id, "session_id": session_id})
    if not doc or not doc.get("messages"):
        return []
    messages = doc["messages"][-limit:]
    history = []
    for msg in messages:
        if msg["role"] == "user":
            history.append(HumanMessage(content=msg["content"]))
        elif msg["role"] == "assistant":
            history.append(AIMessage(content=msg["content"]))
    return history


async def save_message(
    user_id: str,
    session_id: str,
    role: str,
    content: str,
    source: str = "text",
    intent: str = "chat",
) -> None:
    """
    Appends a message to the SPECIFIC session's messages array,
    identified by session_id — not a single shared document anymore.
    """
    db = get_database()
    message = {
        "role": role,
        "content": content,
        "source": source,
        "intent": intent,
        "timestamp": datetime.now(timezone.utc),
    }
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {
            "$push": {"messages": message},
            "$set": {"updated_at": datetime.now(timezone.utc)},
        },
    )


# ─────────────────────────────────────────────────────────────────
# Main Chat — Tool Calling Loop
# ─────────────────────────────────────────────────────────────────
async def chat_with_coco(
    user_id: str,
    user_message: str,
    source: str = "text",
    session_id: str = "",
) -> dict:
    """
    Orchestrator using bind_tools pattern.

    ✅ NEW: now session-aware.
    - If session_id is empty (first message of a new chat), a new
      session document is created automatically and its id returned.
    - All history loads/saves are scoped to this session_id only,
      so different chats never bleed into each other.

    Returns: {"reply": str, "intent": str, "session_id": str}
    """
    try:
        # ✅ Auto-create a session if none was provided (very first
        # message of a brand new chat — Flutter doesn't have an id yet)
        if not session_id:
            new_session = await create_new_session(user_id, first_message=user_message)
            session_id = new_session["session_id"]

        # Step 1 — Load history SCOPED TO THIS SESSION ONLY
        history = await get_conversation_history(user_id, session_id, limit=8)

        # Step 2 — Get all tools for this user
        all_tools = (
            get_task_agent_tools(user_id) +
            get_execution_agent_tools(user_id) +
            get_scheduler_agent_tools(user_id) +
            get_analytics_agent_tools(user_id)
        )
        tool_map = {tool.name: tool for tool in all_tools}
        llm_with_tools = _base_llm.bind_tools(all_tools)

        messages = [SystemMessage(content=SYSTEM_PROMPT)]
        messages.extend(history)
        messages.append(HumanMessage(content=user_message))

        response = await llm_with_tools.ainvoke(messages)
        messages.append(response)

        intent = "chat"
        tool_results = []

        if response.tool_calls:
            for tool_call in response.tool_calls:
                tool_name = tool_call["name"]
                tool_args = tool_call["args"]
                tool_id = tool_call["id"]

                if intent == "chat":
                    intent = tool_name

                if tool_name in tool_map:
                    try:
                        tool_fn = tool_map[tool_name]
                        clean_args = {k: v for k, v in tool_args.items() if v is not None}
                        result = await tool_fn.ainvoke(clean_args)
                        tool_results.append(
                            ToolMessage(content=str(result), tool_call_id=tool_id)
                        )
                    except Exception as e:
                        tool_results.append(
                            ToolMessage(content=f"Tool error: {str(e)}", tool_call_id=tool_id)
                        )
                else:
                    tool_results.append(
                        ToolMessage(content="Tool not found.", tool_call_id=tool_id)
                    )
            messages.extend(tool_results)

            messages.append(HumanMessage(
                content="Based ONLY on the tool result above, give a clear and direct "
                        "response to the user. Do not add information from your own knowledge."
            ))
            final_response = await _base_llm.ainvoke(messages)
            ai_reply = final_response.content.strip()
        else:
            ai_reply = response.content.strip()

        if not ai_reply:
            retry_response = await _base_llm.ainvoke([
                SystemMessage(content="You are CoCo, a friendly AI productivity assistant. Reply conversationally."),
                HumanMessage(content=user_message),
            ])
            ai_reply = retry_response.content.strip()

        if not ai_reply:
            ai_reply = "Got it! Let me know if you need anything else."

        # Step 6 — Save to MongoDB, scoped to this session
        await save_message(user_id, session_id, "user", user_message, source, intent)
        await save_message(user_id, session_id, "assistant", ai_reply, "assistant", intent)

        return {"reply": ai_reply, "intent": intent, "session_id": session_id}

    except Exception as e:
        import traceback
        print(f"❌ ORCHESTRATOR ERROR: {str(e)}")
        print(traceback.format_exc())

        if "rate_limit_exceeded" in str(e) or "429" in str(e):
            error_reply = "I'm a bit overwhelmed right now. Please try again in a few minutes! ⏳"
        else:
            error_reply = "I'm having a moment. Please try again!"

        # Still need a session_id to save the error into, even on failure
        if not session_id:
            new_session = await create_new_session(user_id, first_message=user_message)
            session_id = new_session["session_id"]

        await save_message(user_id, session_id, "user", user_message, source, "chat")
        await save_message(user_id, session_id, "assistant", error_reply, "assistant", "chat")
        return {"reply": error_reply, "intent": "chat", "session_id": session_id}


# ─────────────────────────────────────────────────────────────────
# ✅ NEW: Get history for ONE session (for chat screen)
# ─────────────────────────────────────────────────────────────────
async def get_session_history(user_id: str, session_id: str) -> dict:
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id, "session_id": session_id})
    if not doc:
        return {"messages": [], "session_id": session_id, "title": ""}
    return {
        "messages": doc.get("messages", []),
        "session_id": session_id,
        "title": doc.get("title", "New Chat"),
    }


# ─────────────────────────────────────────────────────────────────
# ✅ NEW: List all sessions for sidebar
# ─────────────────────────────────────────────────────────────────
async def list_user_sessions(user_id: str) -> list:
    """
    Returns lightweight summaries of all the user's chat sessions,
    sorted newest-first — exactly what a ChatGPT-style sidebar needs.
    Deliberately does NOT return full message arrays (keeps this fast
    even if a user has many long chats).
    """
    db = get_database()
    cursor = (
        db["conversations"]
        .find({"user_id": user_id})
        .sort("updated_at", -1)
    )
    docs = await cursor.to_list(length=100)  # cap at 100 chats, plenty for a demo/real use

    summaries = []
    for doc in docs:
        messages = doc.get("messages", [])
        last_preview = ""
        if messages:
            last_msg = messages[-1]
            last_preview = last_msg.get("content", "")[:60]

        summaries.append({
            "session_id": doc.get("session_id", ""),
            "title": doc.get("title", "New Chat"),
            "last_message_preview": last_preview,
            "message_count": len(messages),
            "created_at": doc.get("created_at"),
            "updated_at": doc.get("updated_at"),
        })
    return summaries


# ─────────────────────────────────────────────────────────────────
# ✅ NEW: Delete a session (sidebar "delete chat" action)
# ─────────────────────────────────────────────────────────────────
async def delete_session(user_id: str, session_id: str) -> bool:
    db = get_database()
    result = await db["conversations"].delete_one(
        {"user_id": user_id, "session_id": session_id}
    )
    return result.deleted_count > 0


# ─────────────────────────────────────────────────────────────────
# Manual Briefing Trigger — now creates/uses its own dedicated session
# ─────────────────────────────────────────────────────────────────
async def trigger_manual_briefing(user_id: str) -> str:
    """
    Manually triggers a morning briefing for a user.
    ✅ NOTE: briefings still go to their own logic in proactive_agent.py —
    that file should be updated to save into a dedicated "Daily Briefings"
    session_id (e.g. a deterministic id like f"briefing-{user_id}") rather
    than the old single-document pattern. See proactive_agent.py.
    """
    from app.agents.proactive_agent import _gather_user_context, _generate_briefing_text, _save_briefing
    try:
        context = await _gather_user_context(user_id)
        briefing_text = await _generate_briefing_text(context)
        await _save_briefing(user_id, briefing_text)
        return briefing_text
    except Exception as e:
        return f"Briefing failed: {str(e)}"


async def load_whisper_model():
    from app.crud.voice import load_whisper_model as _load
    await _load()