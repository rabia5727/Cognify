# app/crud/assistant.py
# CoCo — Main AI Orchestrator
# Uses LangChain bind_tools pattern for reliable tool calling with Groq

from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, ToolMessage
from datetime import datetime, timezone
from app.db.connection import get_database
from app.config import settings

# Import all agent tools
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
# Load history from MongoDB
# ─────────────────────────────────────────────────────────────────
async def get_conversation_history(user_id: str, limit: int = 10) -> list:
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id})
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


# ─────────────────────────────────────────────────────────────────
# Save message to MongoDB
# ─────────────────────────────────────────────────────────────────
async def save_message(
    user_id: str,
    role: str,
    content: str,
    source: str = "text",
    intent: str = "chat",
) -> None:
    db = get_database()
    message = {
        "role": role,
        "content": content,
        "source": source,
        "intent": intent,
        "timestamp": datetime.now(timezone.utc),
    }
    await db["conversations"].update_one(
        {"user_id": user_id},
        {"$push": {"messages": message}},
        upsert=True,
    )


# ─────────────────────────────────────────────────────────────────
# Main Chat — Tool Calling Loop
# ─────────────────────────────────────────────────────────────────
async def chat_with_coco(
    user_id: str,
    user_message: str,
    source: str = "text",
) -> str:
    """
    Orchestrator using bind_tools pattern.

    Flow:
    1. Load history
    2. Bind all tools to LLM
    3. LLM decides which tool to call
    4. We execute the tool
    5. Feed result back to LLM for final reply
    6. Save everything to MongoDB
    """
    try:
        # Step 1 — Load history
        history = await get_conversation_history(user_id, limit=8)

        # Step 2 — Get all tools for this user
        all_tools = (
            get_task_agent_tools(user_id) +
            get_execution_agent_tools(user_id) +
            get_scheduler_agent_tools(user_id) +
            get_analytics_agent_tools(user_id)
        )

        # Build tool map for lookup
        tool_map = {tool.name: tool for tool in all_tools}

        # Bind tools to LLM
        llm_with_tools = _base_llm.bind_tools(all_tools)

        # Build message list
        messages = [SystemMessage(content=SYSTEM_PROMPT)]
        messages.extend(history)
        messages.append(HumanMessage(content=user_message))

        # Step 3 — First LLM call — may return tool calls
        response = await llm_with_tools.ainvoke(messages)
        messages.append(response)

        intent = "chat"
        tool_results = []

        # Step 4 — Execute any tool calls
        if response.tool_calls:
            for tool_call in response.tool_calls:
                tool_name = tool_call["name"]
                tool_args = tool_call["args"]
                tool_id = tool_call["id"]

                # Track intent from first tool called
                if intent == "chat":
                    intent = tool_name

                if tool_name in tool_map:
                    try:
                        tool_fn = tool_map[tool_name]
                        # Strip null values — 8b model passes null for optional params
                        # Groq schema validation rejects null, expects absent key
                        clean_args = {k: v for k, v in tool_args.items() if v is not None}
                        result = await tool_fn.ainvoke(clean_args)
                        tool_results.append(
                            ToolMessage(
                                content=str(result),
                                tool_call_id=tool_id,
                            )
                        )
                    except Exception as e:
                        tool_results.append(
                            ToolMessage(
                                content=f"Tool error: {str(e)}",
                                tool_call_id=tool_id,
                            )
                        )
                else:
                    tool_results.append(
                        ToolMessage(
                            content="Tool not found.",
                            tool_call_id=tool_id,
                        )
                    )
            # Add tool results to messages
            messages.extend(tool_results)

            # Step 5 — Second LLM call — forms final reply using tool results
            messages.append(HumanMessage(content="Based ONLY on the tool result above, give a clear and direct response to the user. Do not add information from your own knowledge."))
            final_response = await _base_llm.ainvoke(messages)
            ai_reply = final_response.content.strip()
        else:
            # No tool called — plain conversation
            ai_reply = response.content.strip()

        # If Groq returns empty content, retry with a simpler prompt
        if not ai_reply:
            retry_response = await _base_llm.ainvoke([
                SystemMessage(content="You are CoCo, a friendly AI productivity assistant. Reply conversationally."),
                HumanMessage(content=user_message),
            ])
            ai_reply = retry_response.content.strip()

        if not ai_reply:
            ai_reply = "Got it! Let me know if you need anything else."

        # Step 6 — Save to MongoDB
        await save_message(user_id, "user", user_message, source, intent)
        await save_message(user_id, "assistant", ai_reply, "assistant", intent)

        return ai_reply

    except Exception as e:
        import traceback
        print(f"❌ ORCHESTRATOR ERROR: {str(e)}")
        print(traceback.format_exc())
        
        # Friendly message for rate limit specifically
        if "rate_limit_exceeded" in str(e) or "429" in str(e):
            error_reply = "I'm a bit overwhelmed right now. Please try again in a few minutes! ⏳"
        else:
            error_reply = "I'm having a moment. Please try again!"
        
        await save_message(user_id, "user", user_message, source, "chat")
        await save_message(user_id, "assistant", error_reply, "assistant", "chat")
        return error_reply


# ─────────────────────────────────────────────────────────────────
# Get Full History for Flutter
# ─────────────────────────────────────────────────────────────────
async def get_full_history(user_id: str) -> list:
    db = get_database()
    doc = await db["conversations"].find_one({"user_id": user_id})
    if not doc or not doc.get("messages"):
        return []
    return doc["messages"]


# ─────────────────────────────────────────────────────────────────
# Manual Briefing Trigger — for demo / testing
# ─────────────────────────────────────────────────────────────────
async def trigger_manual_briefing(user_id: str) -> str:
    """
    Manually triggers a morning briefing for a user.
    Bypasses the dedup check so it always fires.
    Use during demo to showcase proactive feature.
    """
    from app.agents.proactive_agent import _gather_user_context, _generate_briefing_text, _save_briefing
    try:
        context = await _gather_user_context(user_id)
        briefing_text = await _generate_briefing_text(context)
        await _save_briefing(user_id, briefing_text)
        return briefing_text
    except Exception as e:
        return f"Briefing failed: {str(e)}"


# ─────────────────────────────────────────────────────────────────
# Whisper preload for main.py lifespan
# ─────────────────────────────────────────────────────────────────
async def load_whisper_model():
    from app.crud.voice import load_whisper_model as _load
    await _load()