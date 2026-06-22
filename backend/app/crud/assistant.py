# app/crud/assistant.py

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


_base_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.7,
    max_tokens=1024,
)

# ── Tools whose output is already user-ready ─────────────────────────────────
# These tools return carefully formatted messages (full document content,
# email drafts, search results, study plans).
# Passing them through a second LLM call causes the LLM to SUMMARIZE
# the output — destroying the formatting and losing content.
# Solution: use the tool result directly as the reply, skip second LLM call.
_PASSTHROUGH_TOOLS = {
    "generate_solution_tool",  # shows full document content
    "edit_document_tool",      # shows updated full content
    "draft_email_tool",        # shows full email draft
    "edit_email_tool",         # shows updated email draft
    "search_topic_tool",       # search results
    "breakdown_task",          # step-by-step plan
    "build_study_plan",        # study plan
    "suggest_resources",       # resource list
}

SYSTEM_PROMPT = """You are CoCo, an intelligent AI productivity assistant inside Cognify.
You help students and freelancers manage tasks, deadlines, projects, and productivity.

CLARIFICATION RULE (HIGHEST PRIORITY):
Before using generate_solution_tool, draft_email_tool, build_study_plan, or breakdown_task,
you MUST check if the request has enough detail to produce good output.

If ANY of these are missing, ask ONE focused question before calling the tool:
- generate_solution_tool needs: topic/subject, key requirements or sections, approximate length
- draft_email_tool needs: recipient, purpose of email, tone (formal/casual)
- build_study_plan needs: subject, exam date or deadline, available hours per day
- breakdown_task needs: what the task actually involves

BAD (too vague to generate well):
  User: "help me with my maths assignment" → ASK: "What topics does it cover and what sections do you need?"
  User: "write me an email" → ASK: "Who is this to and what is it about?"
  User: "make a study plan" → ASK: "Which subject and when is your exam?"

GOOD (enough detail to proceed):
  User: "write an essay on climate change, 500 words, intro + 3 arguments + conclusion" → USE generate_solution_tool
  User: "email to my professor apologizing for missing class" → USE draft_email_tool
  User: "study plan for data structures exam next Friday, 2 hours a day" → USE build_study_plan

Ask only ONE question. Keep it short and friendly. Never ask multiple questions at once.

TOOLS — use them whenever the user's request has enough detail:

Task Management:
- create_task_tool: add/create/schedule a task
- get_user_tasks: see/list/show tasks
- check_deadlines: due dates or urgent tasks
- update_task_status: mark task done/complete
- get_user_projects: show projects

Execution & Learning:
- search_topic_tool: search or look something up on the web
- generate_solution_tool: write complete content for assignment, essay, proposal, or report
  (user reads it in chat first, then decides if they want DOCX or just edits)
- edit_document_tool: edit the document when user requests changes
  (call when user says 'make it longer', 'change the intro', 'add more examples' etc.)
- breakdown_task: plan a complex task step by step
- build_study_plan: study plan for exams or academic work
- create_subtasks: split a task into smaller pieces
- suggest_resources: learning resources for a topic

Email:
- draft_email_tool: write a complete email draft
- edit_email_tool: edit the email when user requests changes

Scheduling & Analytics:
- summarize_day, prioritize_tasks, check_workload_balance, find_free_slots
- get_productivity_score, get_weekly_summary, get_most_active_hour

RULES:
1. ALWAYS ask ONE clarifying question if the request is too vague before using any generation tool.
2. ALWAYS use generate_solution_tool when user provides enough detail about an assignment, essay, proposal, or report.
3. ALWAYS use edit_document_tool when user asks for changes to content just generated.
4. ALWAYS use draft_email_tool when user wants an email written and has given enough context.
5. ALWAYS use edit_email_tool when user asks to change a drafted email.
6. Keep replies concise, friendly, plain text.
7. Never ask more than ONE question at a time."""
# ── Session helpers ──────────────────────────────────────────────────────────

def _generate_title_from_message(message: str) -> str:
    cleaned = message.strip().replace("\n", " ")
    return cleaned if len(cleaned) <= 40 else cleaned[:40].rsplit(" ", 1)[0] + "..."


async def create_new_session(user_id: str, first_message: str = "") -> dict:
    db         = get_database()
    session_id = str(uuid.uuid4())
    title      = _generate_title_from_message(first_message) if first_message else "New Chat"
    await db["conversations"].insert_one({
        "session_id":     session_id,
        "user_id":        user_id,
        "title":          title,
        "messages":       [],
        "pending_action": None,
        "created_at":     datetime.now(timezone.utc),
        "updated_at":     datetime.now(timezone.utc),
    })
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
        from app.crud.email_generator import send_email_via_gmail
        return await send_email_via_gmail(
            to=action.get("to", ""),
            subject=action.get("subject", ""),
            body=action.get("body", ""),
            user_id=user_id,
        )

    return "Action completed."


# ── Confirmation detection ────────────────────────────────────────────────────
# Only clear, unambiguous yes-words trigger execution.
# "make", "create", "go", "do" removed — too ambiguous when editing.

_CONFIRM_WORDS = {
    "yes", "yeah", "yep", "yup",
    "sure", "ok", "okay", "alright",
    "confirmed", "proceed", "perfect",
    "sounds good", "go ahead", "do it",
    "create it", "make it", "let's go",
    "download it", "save it", "send it",
    "create the file", "download the file",
}


def _is_confirmation(message: str) -> bool:
    """Max 6 words — prevents 'make it more formal' triggering DOCX creation."""
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
    try:
        if not session_id:
            new_session = await create_new_session(user_id, first_message=user_message)
            session_id  = new_session["session_id"]

        # ── Confirm-before-execute ────────────────────────────────────────
        pending = await _load_pending_action(user_id, session_id)
        if pending and _is_confirmation(user_message):
            result_text = await _execute_pending_action(pending, user_id=user_id)
            await _clear_pending_action(user_id, session_id)
            intent = "create_docx" if pending.get("type") == "create_docx" else "send_email"
            await save_message(user_id, session_id, "user",      user_message, source,      "confirm")
            await save_message(user_id, session_id, "assistant", result_text,  "assistant", intent)
            return {"reply": result_text, "intent": intent, "session_id": session_id}

        # ── Normal tool-calling flow ──────────────────────────────────────
        history = await get_conversation_history(user_id, session_id, limit=8)

        all_tools = (
            get_task_agent_tools(user_id) +
            get_execution_agent_tools(user_id, session_id) +
            get_scheduler_agent_tools(user_id) +
            get_analytics_agent_tools(user_id)
        )
        tool_map       = {t.name: t for t in all_tools}
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

            # ── ✅ KEY FIX: skip second LLM for formatting tools ──────────
            # These tools already return perfectly formatted user-facing messages.
            # Running them through a second LLM call causes summarization/compression
            # which loses the full document content, email body, etc.
            if intent in _PASSTHROUGH_TOOLS:
                ai_reply = "\n\n".join(tr.content for tr in tool_results)
            else:
                # For data tools (task lists, stats etc.) — LLM formats the raw output
                messages.extend(tool_results)
                messages.append(HumanMessage(
                    content=(
                        "Based ONLY on the tool result above, give a clear and direct response. "
                        "Do not add information from your own knowledge. "
                        "If the result contains a [FILE:...] tag, tell the user their "
                        "document is ready to download."
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