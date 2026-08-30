# app/crud/assistant.py

import os
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
    model=settings.ORCHESTRATOR_MODEL,
    temperature=0.7,
    max_tokens=1024,
    timeout=20,
    max_retries=0,  # a same-model retry just delays reaching the fallback below
)

# Backup model, tried only if the primary model's call fails or times out —
# same Groq account, no extra signup. gpt-oss needs reasoning_effort="low"
# (see _classify_tool_categories) so it doesn't burn its token budget on
# hidden reasoning before ever producing visible content; llama models
# don't use/need that param.
_base_llm_fallback = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.ORCHESTRATOR_FALLBACK_MODEL,
    temperature=0.7,
    max_tokens=1024,
    timeout=20,
    max_retries=1,
    reasoning_effort="low",
)

# Cheap/fast pre-router — decides which tool category (if any) a message
# needs, so the big orchestrator only binds relevant tool schemas instead of
# all ~21 on every single message (see _classify_tool_categories below).
_router_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.LIGHTWEIGHT_MODEL,
    temperature=0,
    max_tokens=80,
    timeout=8,
    max_retries=0,
)

_router_llm_fallback = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.LIGHTWEIGHT_FALLBACK_MODEL,
    temperature=0,
    max_tokens=80,
    timeout=8,
    max_retries=1,
    reasoning_effort="low",
)


async def _ainvoke_with_fallback(primary, fallback, messages):
    """
    Try the primary model; on ANY failure (timeout, connection error, model
    outage) retry once with a different backup model instead of failing the
    whole request. A problem specific to one model no longer takes the
    assistant down — it just costs one extra round trip.
    """
    try:
        return await primary.ainvoke(messages)
    except Exception as e:
        print(f"⚠️ Primary model failed ({type(e).__name__}: {e}) — retrying with fallback model")
        return await fallback.ainvoke(messages)

_ROUTER_PROMPT = """You are a fast intent router. Decide which tool categories \
(if any) are needed to handle the user's message. Reply with ONLY a \
comma-separated list using these exact words: task, execution, schedule, none.

- task: creating, listing, updating tasks/projects; checking deadlines/status
- execution: writing essays/assignments/reports, researching a topic, \
drafting/editing emails, breaking a task into steps, building a study plan, \
suggesting resources
- schedule: summarizing the day, prioritizing tasks, workload balance, free \
time slots, productivity score, weekly summary, most active hours
- none: greetings, thanks, small talk, or anything not needing a tool

If the message could span more than one category, list all that apply. If \
unsure, list all three. Reply with only the category words, nothing else."""

_TOOL_CATEGORIES = {"task", "execution", "schedule"}


async def _classify_tool_categories(user_message: str) -> set:
    """
    Which tool category schema(s) the orchestrator actually needs for this
    message. Falls back to "all categories" (the old always-bind-everything
    behavior) on any router failure or ambiguous response, so a bad
    classification only costs speed, never capability.
    """
    try:
        response = await _ainvoke_with_fallback(_router_llm, _router_llm_fallback, [
            SystemMessage(content=_ROUTER_PROMPT),
            HumanMessage(content=user_message),
        ])
        raw   = (response.content or "").strip().lower()
        found = {cat for cat in _TOOL_CATEGORIES if cat in raw}
        if found:
            return found
        if "none" in raw:
            return set()
        return set(_TOOL_CATEGORIES)  # unrecognized reply — be safe
    except Exception:
        return set(_TOOL_CATEGORIES)  # router itself failed — be safe

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
DOCUMENTS_DIR = os.path.join(_PROJECT_ROOT, "generated_documents")

_PASSTHROUGH_TOOLS = {
    "generate_solution_tool",
    "edit_document_tool",
    "draft_email_tool",
    "edit_email_tool",
    "search_topic_tool",
    "breakdown_task",
    "build_study_plan",
    "suggest_resources",
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
        content = msg["content"]

        if (
            msg["role"] == "assistant"
            and msg.get("intent") in _PASSTHROUGH_TOOLS
            and len(content) > 400
        ):
            content = f"[Earlier generated {msg['intent']} — already shown to user, {len(content)} characters]"

        if msg["role"] == "user":
            history.append(HumanMessage(content=content))
        elif msg["role"] == "assistant":
            history.append(AIMessage(content=content))

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


async def _set_pending_action(user_id: str, session_id: str, action: dict) -> None:
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {"$set": {"pending_action": action, "updated_at": datetime.now(timezone.utc)}},
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

        db = get_database()
        await db["conversations"].update_one(
            {"user_id": user_id, "session_id": action.get("session_id", "")},
            {"$set": {
                "pending_action": {
                    "type": "ask_submit_classroom",
                    "filename": filename,
                    "title": action.get("title", "Document"),
                },
                "updated_at": datetime.now(timezone.utc),
            }},
        )

        return (
            f"✅ Your document is ready!\n\n"
            f"📄 **{action.get('title', 'Document')}**\n"
            f"Tap below to download your DOCX file.\n\n"
            f"[FILE:{filename}]\n\n"
            f"📤 Want me to submit this to Google Classroom for you? (yes/no)"
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

_CONFIRM_WORDS = {
    "yes", "yeah", "yep", "yup",
    "sure", "ok", "okay", "alright",
    "confirmed", "proceed", "perfect",
    "sounds good", "go ahead", "do it",
    "create it", "make it", "let's go",
    "download it", "save it", "send it",
    "create the file", "download the file",
}

_DECLINE_WORDS = {"no", "nope", "not now", "no thanks", "skip", "cancel"}


def _is_confirmation(message: str) -> bool:
    cleaned = message.lower().strip().rstrip("!.,?")
    return cleaned in _CONFIRM_WORDS


def _is_decline(message: str) -> bool:
    cleaned = message.lower().strip().rstrip("!.,?")
    return cleaned in _DECLINE_WORDS


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

        pending = await _load_pending_action(user_id, session_id)

        # ── STEP A: "Want me to submit this to Classroom?" ───────────────
        if pending and pending.get("type") == "ask_submit_classroom":
            if _is_confirmation(user_message):
                reply = "Great! Which class is this for?"
                await _set_pending_action(user_id, session_id, {
                    "type": "awaiting_classroom_selection",
                    "filename": pending.get("filename"),
                    "title": pending.get("title"),
                })
                await save_message(user_id, session_id, "user", user_message, source, "confirm")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "ask_classroom_selection")
                return {"reply": reply, "intent": "ask_classroom_selection", "session_id": session_id}

            elif _is_decline(user_message):
                reply = "No problem! Let me know if you need anything else."
                await _clear_pending_action(user_id, session_id)
                await save_message(user_id, session_id, "user", user_message, source, "decline")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
                return {"reply": reply, "intent": "chat", "session_id": session_id}

            reply = "Sorry, just to confirm — do you want me to submit this to Google Classroom? (yes/no)"
            await save_message(user_id, session_id, "user", user_message, source, "chat")
            await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
            return {"reply": reply, "intent": "chat", "session_id": session_id}

        # ── STEP B1: "Which class?" ───────────────────────────────────────
        if pending and pending.get("type") == "awaiting_classroom_selection":
            from app.services.google_classroom import GoogleClassroomService
            import difflib

            db = get_database()
            course_query = user_message.strip().strip("'\"")

            courses = await GoogleClassroomService.fetch_courses(user_id, db)
            course_names = [c.get("name", "") for c in courses]
            course_match = difflib.get_close_matches(course_query, course_names, n=1, cutoff=0.35)

            if not course_match:
                reply = (
                    f"I couldn't find a class matching '{course_query}'. "
                    f"Your classes are: {', '.join(course_names) if course_names else 'none found'}. "
                    f"Which class is this for?"
                )
                await save_message(user_id, session_id, "user", user_message, source, "chat")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
                return {"reply": reply, "intent": "chat", "session_id": session_id}

            matched_course = next(c for c in courses if c.get("name") == course_match[0])

            await _set_pending_action(user_id, session_id, {
                "type": "awaiting_assignment_selection",
                "filename": pending.get("filename"),
                "title": pending.get("title"),
                "course_id": matched_course.get("id"),
                "course_name": matched_course.get("name"),
            })

            reply = f"Got it — **{matched_course.get('name')}**. Which assignment is this for?"
            await save_message(user_id, session_id, "user", user_message, source, "confirm")
            await save_message(user_id, session_id, "assistant", reply, "assistant", "ask_assignment")
            return {"reply": reply, "intent": "ask_assignment", "session_id": session_id}

        # ── STEP B2: "Which assignment?" ──────────────────────────────────
        if pending and pending.get("type") == "awaiting_assignment_selection":
            from app.services.google_classroom import GoogleClassroomService
            import difflib

            db = get_database()
            assignment_query = user_message.strip().strip("'\"")
            course_id = pending.get("course_id")

            assignments = await GoogleClassroomService.fetch_assignments(user_id, course_id, db)
            assignment_titles = [a.get("title", "") for a in assignments]
            assignment_match = difflib.get_close_matches(assignment_query, assignment_titles, n=1, cutoff=0.35)

            if not assignment_match:
                reply = (
                    f"Couldn't find an assignment matching '{assignment_query}' in "
                    f"{pending.get('course_name')}. Assignments there: "
                    f"{', '.join(assignment_titles) if assignment_titles else 'none found'}. "
                    f"Which assignment is this for?"
                )
                await save_message(user_id, session_id, "user", user_message, source, "chat")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
                return {"reply": reply, "intent": "chat", "session_id": session_id}

            matched_assignment = next(a for a in assignments if a.get("title") == assignment_match[0])

            await _set_pending_action(user_id, session_id, {
                "type": "confirmed_classroom_match",
                "filename": pending.get("filename"),
                "title": pending.get("title"),
                "course_id": course_id,
                "course_name": pending.get("course_name"),
                "assignment_id": matched_assignment.get("id"),
                "assignment_title": matched_assignment.get("title"),
                "alternate_link": matched_assignment.get("alternateLink", ""),
            })

            reply = (
                f"Found it! 📚 **{pending.get('course_name')}** → "
                f"📝 **{matched_assignment.get('title')}**\n\n"
                f"Shall I go ahead and submit your document there? (yes/no)"
            )
            await save_message(user_id, session_id, "user", user_message, source, "confirm")
            await save_message(user_id, session_id, "assistant", reply, "assistant", "classroom_match_found")
            return {"reply": reply, "intent": "classroom_match_found", "session_id": session_id}

        # ── STEP C: Final confirm → upload to Drive → give assignment link ─
        if pending and pending.get("type") == "confirmed_classroom_match":
            if _is_decline(user_message):
                reply = "Okay, I won't submit it. Let me know if you need anything else."
                await _clear_pending_action(user_id, session_id)
                await save_message(user_id, session_id, "user", user_message, source, "decline")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
                return {"reply": reply, "intent": "chat", "session_id": session_id}

            if _is_confirmation(user_message):
                from app.services.google_drive_service import GoogleDriveService

                db = get_database()
                filename = pending.get("filename")
                filepath = os.path.join(DOCUMENTS_DIR, filename)

                try:
                    if not os.path.exists(filepath):
                        raise Exception("Generated file could not be found on the server")

                    with open(filepath, "rb") as f:
                        file_bytes = f.read()

                    # Upload the .docx to Google Drive (this part always works)
                    drive_result = await GoogleDriveService.upload_file(
                        user_id=user_id,
                        db=db,
                        file_content=file_bytes,
                        file_name=filename,
                        mime_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    )

                    await db["drive_uploads"].insert_one({
                        "user_id": user_id,
                        "assignment_id": pending.get("assignment_id"),
                        "course_id": pending.get("course_id"),
                        "file_id": drive_result["file_id"],
                        "file_name": filename,
                        "share_link": drive_result["share_link"],
                        "created_at": datetime.now(timezone.utc),
                    })

                    # NOTE: Google restricts studentSubmissions.modifyAttachments/turnIn
                    # to specially-verified apps, so we can't submit programmatically.
                    # Instead: upload to Drive, then hand the user a direct link to the
                    # exact assignment — tapping it opens the assignment page directly,
                    # so all that's left is one tap on "Turn In".
                    assignment_link = pending.get("alternate_link") or (
                        f"https://classroom.google.com/c/{pending.get('course_id')}"
                    )

                    reply = (
                        f"✅ Uploaded to Drive! Your document is ready for "
                        f"**{pending.get('assignment_title')}** in **{pending.get('course_name')}**.\n\n"
                        f"Just tap below to open the assignment — attach the file and hit **Turn In**.\n\n"
                        f"[CLASSROOM_LINK:{assignment_link}]"
                    )
                except Exception as e:
                    reply = f"Something went wrong while submitting: {str(e)}"

                await _clear_pending_action(user_id, session_id)
                await save_message(user_id, session_id, "user", user_message, source, "confirm")
                await save_message(user_id, session_id, "assistant", reply, "assistant", "classroom_submitted")
                return {"reply": reply, "intent": "classroom_submitted", "session_id": session_id}

            reply = "Just to confirm — should I go ahead and submit it now? (yes/no)"
            await save_message(user_id, session_id, "user", user_message, source, "chat")
            await save_message(user_id, session_id, "assistant", reply, "assistant", "chat")
            return {"reply": reply, "intent": "chat", "session_id": session_id}

        # ── Original DOCX confirm-before-execute (unrelated pending types) ─
        if pending and _is_confirmation(user_message):
            pending["session_id"] = session_id
            action_type = pending.get("type")
            result_text = await _execute_pending_action(pending, user_id=user_id)

            if action_type != "create_docx":
                await _clear_pending_action(user_id, session_id)

            intent = "create_docx" if action_type == "create_docx" else "send_email"
            await save_message(user_id, session_id, "user",      user_message, source,      "confirm")
            await save_message(user_id, session_id, "assistant", result_text,  "assistant", intent)
            return {"reply": result_text, "intent": intent, "session_id": session_id}

        # ── Normal tool-calling flow ──────────────────────────────────────
        history = await get_conversation_history(user_id, session_id, limit=8)

        # Only bind the tool category schemas this message actually needs.
        # get_execution_agent_tools() already includes the document-agent
        # tools (search_topic_tool, generate_solution_tool, edit_document_tool)
        # internally, so it isn't listed separately here.
        categories = await _classify_tool_categories(user_message)

        # The router classifies each message in isolation, with no idea a
        # draft is already sitting in pending_action — so a terse edit like
        # "change the recipient to x@y.com" doesn't obviously read as
        # "execution" work and the router can return none at all. If a
        # send_email/create_docx draft is still awaiting confirmation,
        # keep edit_email_tool/edit_document_tool available regardless of
        # what the router decided, so an edit request never falls through
        # to a generic chat reply that ignores the pending draft entirely.
        if pending and pending.get("type") in ("send_email", "create_docx"):
            categories.add("execution")

        active_tools = []
        if "task" in categories:
            active_tools += get_task_agent_tools(user_id)
        if "execution" in categories:
            active_tools += get_execution_agent_tools(user_id, session_id)
        if "schedule" in categories:
            active_tools += get_scheduler_agent_tools(user_id) + get_analytics_agent_tools(user_id)

        tool_map = {t.name: t for t in active_tools}
        llm_with_tools = _base_llm.bind_tools(active_tools) if active_tools else _base_llm
        llm_with_tools_fallback = (
            _base_llm_fallback.bind_tools(active_tools) if active_tools else _base_llm_fallback
        )

        messages = [SystemMessage(content=SYSTEM_PROMPT)]
        messages.extend(history)
        messages.append(HumanMessage(content=user_message))

        response = await _ainvoke_with_fallback(llm_with_tools, llm_with_tools_fallback, messages)
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

            if intent in _PASSTHROUGH_TOOLS:
                ai_reply = "\n\n".join(tr.content for tr in tool_results)
            else:
                messages.extend(tool_results)
                messages.append(HumanMessage(
                    content=(
                        "Based ONLY on the tool result above, give a clear and direct response. "
                        "Do not add information from your own knowledge. "
                        "If the result contains a [FILE:...] tag, tell the user their "
                        "document is ready to download."
                    )
                ))
                final    = await _ainvoke_with_fallback(_base_llm, _base_llm_fallback, messages)
                ai_reply = final.content.strip()
        else:
            ai_reply = response.content.strip()

        if not ai_reply:
            retry    = await _ainvoke_with_fallback(_base_llm, _base_llm_fallback, [
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
        error_type = type(e).__name__
        print(f"❌ ORCHESTRATOR ERROR [{error_type}]: {str(e)}")
        print(traceback.format_exc())

        if error_type in ("RateLimitError", "APIStatusError") and "429" in str(e):
            error_reply = "I'm a bit overwhelmed right now. Please try again in a moment! ⏳"
        elif error_type in ("APITimeoutError", "TimeoutError"):
            error_reply = "That took a bit too long — mind trying again? ⏳"
        elif error_type == "APIConnectionError":
            error_reply = "I'm having trouble connecting right now. Check your internet and try again!"
        else:
            error_reply = "I'm having a moment. Please try again!"

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