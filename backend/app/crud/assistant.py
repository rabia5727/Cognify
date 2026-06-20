# app/crud/assistant.py
# CoCo — Main AI Orchestrator
#
# Changes this session:
# ✅ Email agent tools added to tool pool
# ✅ _execute_pending_action handles "send_email" type
# ✅ _CONFIRM_WORDS cleaned up — removed ambiguous words like
#    "create", "make", "go", "do" that caused false positives
#    when user said "make it more formal" with a pending action
# ✅ SYSTEM_PROMPT updated with email + edit tool descriptions

import uuid
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, ToolMessage
from datetime import datetime, timezone
from app.db.connection import get_database
from app.config import settings

from app.agents.task_agent      import get_task_agent_tools
from app.agents.execution_agent import get_execution_agent_tools
from app.agents.scheduler_agent import get_scheduler_agent_tools
from app.agents.analytics_agent import get_analytics_agent_tools
from app.agents.email_agent     import get_email_agent_tools       # ✅ NEW


# ── LLM ─────────────────────────────────────────────────────────────────────

_base_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.7,
    max_tokens=1024,
)

SYSTEM_PROMPT = """You are CoCo, an intelligent AI productivity assistant inside Cognify.
You help students and freelancers manage tasks, deadlines, projects, and productivity.

TOOLS — use them whenever the user's request matches:

Task Management:
- create_task_tool: add/create/schedule a task
- get_user_tasks: see/list/show tasks
- check_deadlines: due dates or urgent tasks
- update_task_status: mark task done/complete
- get_user_projects: show projects

Execution & Learning:
- search_topic_tool: search or look something up on the web
- generate_solution_tool: write a complete assignment, essay, proposal, or report as a DOCX
- edit_document_tool: edit/change the document draft when user requests modifications
  (IMPORTANT: call this when user says things like 'make it longer', 'change the intro',
  'add more examples', 'rewrite the conclusion' AFTER a document was generated)
- breakdown_task: plan a complex task step by step
- build_study_plan: study plan for exams or academic work
- create_subtasks: split a task into smaller pieces
- suggest_resources: learning resources for a topic

Email:
- draft_email_tool: write a complete email draft (academic, freelance, general)
- edit_email_tool: edit the email draft when user requests changes
  (call when user says 'make it more formal', 'shorten it', 'change the subject' etc.)

Scheduling & Analytics:
- summarize_day, prioritize_tasks, check_workload_balance, find_free_slots
- get_productivity_score, get_weekly_summary, get_most_active_hour

RULES:
1. ALWAYS use generate_solution_tool when user wants something written as a document.
2. ALWAYS use edit_document_tool when a document was generated and user asks for changes.
3. ALWAYS use draft_email_tool when user wants an email written.
4. ALWAYS use edit_email_tool when an email draft exists and user asks for changes.
5. Keep replies concise, friendly, plain text."""


# ── Session helpers ──────────────────────────────────────────────────────────

def _generate_title_from_message(message: str) -> str:
    cleaned = message.strip().replace("\n", " ")
    return cleaned if len(cleaned) <= 40 else cleaned[:40].rsplit(" ", 1)[0] + "..."


async def create_new_session(user_id: str, first_message: str = "") -> dict:
    db         = get_database()
    session_id = str(uuid.uuid4())
    title      = _generate_title_from_message(first_message) if first_message else "New Chat"
    doc = {
        "session_id":     session_id,
        "user_id":        user_id,
        "title":          title,
        "messages":       [],
        "pending_action": None,
        "created_at":     datetime.now(timezone.utc),
        "updated_at":     datetime.now(timezone.utc),
    }
    await db["conversations"].insert_one(doc)
    return {"session_id": session_id, "title": title}


async def get_conversation_history(user_id: str, session_id: str, limit: int = 8) -> list:
    db  = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id, "session_id": session_id})
    if not doc or not doc.get("messages"):
        return []
    history = []
    for msg in doc["messages"][-limit:]:
        if msg["role"] == "user":
            history.append(HumanMessage(content=msg["content"]))
        elif msg["role"] == "assistant":
            history.append(AIMessage(content=msg["content"]))
    return history


async def save_message(
    user_id: str, session_id: str, role: str,
    content: str, source: str = "text", intent: str = "chat",
) -> None:
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {
            "$push": {"messages": {
                "role": role, "content": content,
                "source": source, "intent": intent,
                "timestamp": datetime.now(timezone.utc),
            }},
            "$set": {"updated_at": datetime.now(timezone.utc)},
        },
    )


# ── Pending action helpers ────────────────────────────────────────────────────

async def _load_pending_action(user_id: str, session_id: str) -> dict | None:
    db  = get_database()
    doc = await db["conversations"].find_one(
        {"user_id": user_id, "session_id": session_id},
        {"pending_action": 1},
    )
    return doc.get("pending_action") if doc else None


async def _clear_pending_action(user_id: str, session_id: str) -> None:
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {"$set": {"pending_action": None, "updated_at": datetime.now(timezone.utc)}},
    )


async def _execute_pending_action(action: dict, user_id: str = "") -> str:
    """
    Executes a confirmed pending action.
    Handles: create_docx, send_email
    """
    action_type = action.get("type")

    if action_type == "create_docx":
        from app.crud.document_generator import create_assignment_docx
        filename = await create_assignment_docx(
            title=action.get("title", "Document"),
            content=action.get("content", ""),
            subject=action.get("subject", "General"),
        )
        return (
            f"✅ Your document is ready!\n\n"
            f"📄 **{action.get('title', 'Document')}**\n"
            f"Tap below to download your DOCX file.\n\n"
            f"[FILE:{filename}]"
        )

    elif action_type == "send_email":
        # ✅ Rabia's Gmail send function is called here
        from app.crud.email_generator import send_email_via_gmail
        result = await send_email_via_gmail(
            to=action.get("to", ""),
            subject=action.get("subject", ""),
            body=action.get("body", ""),
            user_id=user_id,
        )
        return result

    return "Action completed."


# ── ✅ FIXED: Confirmation detection ─────────────────────────────────────────
# Removed ambiguous words: "create", "make", "go", "do", "generate", "build"
# These caused false positives — e.g. "make it more formal" (4 words) was
# being treated as a confirmation when a pending_action existed.
# Now only clear, unambiguous yes-words trigger execution.

_CONFIRM_WORDS = {
    "yes", "yeah", "yep", "yup",
    "sure", "ok", "okay", "alright",
    "confirmed", "proceed", "great", "perfect",
    "sounds good", "go ahead", "do it",
    "create it", "make it", "let's go",
    "download it", "save it", "send it",
}


def _is_confirmation(message: str) -> bool:
    """
    Returns True only for short, clear confirmation messages.
    Max 6 words to avoid catching edit requests like
    'make the intro longer' or 'change the tone'.
    """
    cleaned = message.lower().strip().rstrip("!.,?")
    words   = cleaned.split()
    if len(words) > 6:
        return False
    return cleaned in _CONFIRM_WORDS or bool(set(words) & _CONFIRM_WORDS)


# ── Main chat function ────────────────────────────────────────────────────────

async def chat_with_coco(
    user_id: str,
    user_message: str,
    source: str = "text",
    session_id: str = "",
) -> dict:
    """
    Orchestrator using bind_tools pattern.
    Session-aware + confirm-before-execute for documents and emails.
    Returns: {"reply": str, "intent": str, "session_id": str}
    """
    try:
        if not session_id:
            new_session = await create_new_session(user_id, first_message=user_message)
            session_id  = new_session["session_id"]

        # ── Confirm-before-execute check ──────────────────────────────────
        pending = await _load_pending_action(user_id, session_id)
        if pending and _is_confirmation(user_message):
            result_text = await _execute_pending_action(pending, user_id=user_id)
            await _clear_pending_action(user_id, session_id)
            intent = "create_docx" if pending.get("type") == "create_docx" else "send_email"
            await save_message(user_id, session_id, "user",      user_message, source,       "confirm")
            await save_message(user_id, session_id, "assistant", result_text,  "assistant",  intent)
            return {"reply": result_text, "intent": intent, "session_id": session_id}

        # If there's a pending action but user is NOT confirming (they want to edit),
        # let the LLM handle it — edit_document_tool or edit_email_tool will be called.
        # Do NOT clear the pending action here; the edit tools update it in place.

        # ── Normal tool-calling flow ──────────────────────────────────────
        history = await get_conversation_history(user_id, session_id, limit=8)

        all_tools = (
            get_task_agent_tools(user_id) +
            get_execution_agent_tools(user_id, session_id) +
            get_email_agent_tools(user_id, session_id) +          # ✅ NEW
            get_scheduler_agent_tools(user_id) +
            get_analytics_agent_tools(user_id)
        )
        tool_map       = {tool.name: tool for tool in all_tools}
        llm_with_tools = _base_llm.bind_tools(all_tools)

        messages = [SystemMessage(content=SYSTEM_PROMPT)]
        messages.extend(history)
        messages.append(HumanMessage(content=user_message))

        response = await llm_with_tools.ainvoke(messages)
        messages.append(response)

        intent       = "chat"
        tool_results = []

        if response.tool_calls:
            for tool_call in response.tool_calls:
                tool_name = tool_call["name"]
                tool_args = tool_call["args"]
                tool_id   = tool_call["id"]

                if intent == "chat":
                    intent = tool_name

                if tool_name in tool_map:
                    try:
                        clean_args = {k: v for k, v in tool_args.items() if v is not None}
                        result     = await tool_map[tool_name].ainvoke(clean_args)
                        tool_results.append(ToolMessage(content=str(result), tool_call_id=tool_id))
                    except Exception as e:
                        tool_results.append(ToolMessage(content=f"Tool error: {str(e)}", tool_call_id=tool_id))
                else:
                    tool_results.append(ToolMessage(content="Tool not found.", tool_call_id=tool_id))

            messages.extend(tool_results)
            messages.append(HumanMessage(
                content=(
                    "Based ONLY on the tool result above, give a clear and direct response. "
                    "Do not add information from your own knowledge. "
                    "If the result contains a [FILE:...] tag, tell the user their document "
                    "is ready to download."
                )
            ))
            final    = await _base_llm.ainvoke(messages)
            ai_reply = final.content.strip()
        else:
            ai_reply = response.content.strip()

        if not ai_reply:
            retry    = await _base_llm.ainvoke([
                SystemMessage(content="You are CoCo, a friendly AI productivity assistant."),
                HumanMessage(content=user_message),
            ])
            ai_reply = retry.content.strip()

        if not ai_reply:
            ai_reply = "Got it! Let me know if you need anything else."

        await save_message(user_id, session_id, "user",      user_message, source,      intent)
        await save_message(user_id, session_id, "assistant", ai_reply,     "assistant", intent)
        return {"reply": ai_reply, "intent": intent, "session_id": session_id}

    except Exception as e:
        import traceback
        print(f"❌ ORCHESTRATOR ERROR: {str(e)}")
        print(traceback.format_exc())

        error_reply = (
            "I'm a bit overwhelmed right now. Please try again in a moment! ⏳"
            if "rate_limit" in str(e) or "429" in str(e)
            else "I'm having a moment. Please try again!"
        )

        if not session_id:
            new_session = await create_new_session(user_id, first_message=user_message)
            session_id  = new_session["session_id"]

        await save_message(user_id, session_id, "user",      user_message, source,      "chat")
        await save_message(user_id, session_id, "assistant", error_reply,  "assistant", "chat")
        return {"reply": error_reply, "intent": "chat", "session_id": session_id}


# ── Session management ────────────────────────────────────────────────────────

async def get_session_history(user_id: str, session_id: str) -> dict:
    db  = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id, "session_id": session_id})
    if not doc:
        return {"messages": [], "session_id": session_id, "title": ""}
    return {"messages": doc.get("messages", []), "session_id": session_id, "title": doc.get("title", "New Chat")}


async def list_user_sessions(user_id: str) -> list:
    db     = get_database()
    cursor = db["conversations"].find({"user_id": user_id}).sort("updated_at", -1)
    docs   = await cursor.to_list(length=100)
    return [
        {
            "session_id":           doc.get("session_id", ""),
            "title":                doc.get("title", "New Chat"),
            "last_message_preview": (doc.get("messages") or [{}])[-1].get("content", "")[:60],
            "message_count":        len(doc.get("messages", [])),
            "created_at":           doc.get("created_at"),
            "updated_at":           doc.get("updated_at"),
        }
        for doc in docs
    ]


async def delete_session(user_id: str, session_id: str) -> bool:
    db     = get_database()
    result = await db["conversations"].delete_one({"user_id": user_id, "session_id": session_id})
    return result.deleted_count > 0


async def trigger_manual_briefing(user_id: str) -> str:
    from app.agents.proactive_agent import _gather_user_context, _generate_briefing_text, _save_briefing
    try:
        context       = await _gather_user_context(user_id)
        briefing_text = await _generate_briefing_text(context)
        await _save_briefing(user_id, briefing_text)
        return briefing_text
    except Exception as e:
        return f"Briefing failed: {str(e)}"


async def load_whisper_model():
    from app.crud.voice import load_whisper_model as _load
    await _load()