# app/agents/execution_agent.py
# Execution Agent — main coordinator for all "do real work" tools
#
# This file is intentionally thin. It imports tools from sub-agents
# and adds its own task-execution tools (breakdown, study plan, etc).
#
# Sub-agents:
#   document_agent.py — search + generate + edit documents
#   email_agent.py    — draft + edit emails
#
# Tools owned directly here:
#   breakdown_task    — step-by-step task planning
#   build_study_plan  — academic study planning
#   create_subtasks   — creates subtasks in DB
#   suggest_resources — learning resource suggestions

from langchain_core.tools import tool
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings
from app.models.task import TaskCreate
from app.crud.task import create_task
from datetime import datetime, timezone, timedelta

# ── Sub-agent imports ────────────────────────────────────────────────────────
from app.agents.document_agent import get_document_agent_tools
from app.agents.email_agent    import get_email_agent_tools


# ── LLM (8b for lightweight execution tools) ─────────────────────────────────
_execution_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.LIGHTWEIGHT_MODEL,
    temperature=0.4,
    max_tokens=1024,
    timeout=20,
    max_retries=2,
)

# ─────────────────────────────────────────────────────────────────────────────
# Tool 1 — Breakdown Task
# ─────────────────────────────────────────────────────────────────────────────
def get_breakdown_task_tool(user_id: str, session_id: str):
    @tool
    async def breakdown_task(
        task_title: str,
        task_type: str = "general",
        available_hours: float = 2.0,
    ) -> str:
        """
        Break down a complex task into actionable steps.
        Use when user says: 'help me with', 'how do I do', 'break down task',
        'help me plan', 'I need to work on', 'guide me through'.
        """
        try:
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a productivity assistant. Be concise."),
                HumanMessage(content=f"""Break down this task into clear steps in {available_hours} hours.
Task: {task_title}
Type: {task_type}
Return: 1. Brief overview  2. 3-6 steps with time estimates  3. Motivational closing
Plain text only."""),
            ])
            return response.content.strip()
        except Exception as e:
            return f"Failed to breakdown task: {str(e)}"
    return breakdown_task


# ─────────────────────────────────────────────────────────────────────────────
# Tool 2 — Build Study Plan
# ─────────────────────────────────────────────────────────────────────────────
def get_study_plan_tool(user_id: str, session_id: str):
    @tool
    async def build_study_plan(
        subject: str,
        topics: str,
        due_date: str = "tomorrow",
        available_hours: float = 3.0,
    ) -> str:
        """
        Create a detailed study plan for an academic task.
        Use when user says: 'help me study', 'I have an exam',
        'need to prepare for', 'study plan for', 'review for quiz'.
        """
        try:
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a study planning assistant."),
                HumanMessage(content=f"""Create a focused study plan:
Subject: {subject}  Topics: {topics}  Due: {due_date}  Time: {available_hours} hours
Include: 1. Study order  2. Time per topic  3. Specific actions  4. Quick review tips
Plain text only."""),
            ])
            return f"📚 Study Plan for {subject}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to build study plan: {str(e)}"
    return build_study_plan


# ─────────────────────────────────────────────────────────────────────────────
# Tool 3 — Create Subtasks
# ─────────────────────────────────────────────────────────────────────────────
def get_create_subtasks_tool(user_id: str, session_id: str):
    @tool
    async def create_subtasks(
        parent_task_title: str,
        subtask_titles: str,
        due_date: str = "",
    ) -> str:
        """
        Create multiple subtasks for a main task automatically.
        Use when user says: 'break this into subtasks', 'create steps for',
        'add subtasks', 'split task into parts'.
        """
        try:
            titles = [t.strip() for t in subtask_titles.split(",") if t.strip()]
            if not titles:
                return "No subtask titles provided."

            parsed_due = None
            if due_date and due_date.lower() == "tomorrow":
                parsed_due = (datetime.now(timezone.utc) + timedelta(days=1)).replace(
                    hour=23, minute=59, second=0, microsecond=0
                )

            created = []
            for title in titles:
                task = await create_task(
                    TaskCreate(
                        title=title,
                        description=f"Subtask of: {parent_task_title}",
                        priority="medium",
                        category="general",
                        due_date=parsed_due,
                        source="manual",
                    ),
                    user_id,
                )
                created.append(task.title)

            return (
                f"✅ Created {len(created)} subtasks for '{parent_task_title}':\n"
                + "\n".join(f"• {t}" for t in created)
            )
        except Exception as e:
            return f"Failed to create subtasks: {str(e)}"
    return create_subtasks


# ─────────────────────────────────────────────────────────────────────────────
# Tool 4 — Suggest Resources
# ─────────────────────────────────────────────────────────────────────────────
def get_suggest_resources_tool(user_id: str, session_id: str):
    @tool
    async def suggest_resources(topic: str, level: str = "undergraduate") -> str:
        """
        Suggest learning resources and approaches for a topic.
        Use when user says: 'how do I learn', 'resources for',
        'where to start with', 'tips for studying', 'help me understand'.
        """
        try:
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a helpful study assistant."),
                HumanMessage(content=f"""Suggest practical learning resources:
Topic: {topic}  Level: {level}
Include: 1. Best approach  2. 2-3 resource types  3. Key concepts  4. Common mistakes
Plain text only."""),
            ])
            return f"💡 Resources for {topic}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to suggest resources: {str(e)}"
    return suggest_resources


# ─────────────────────────────────────────────────────────────────────────────
# Export — combines all sub-agent tools + own tools
# ─────────────────────────────────────────────────────────────────────────────
def get_execution_agent_tools(user_id: str, session_id: str = "") -> list:
    return [
        # ── Document sub-agent ───────────────────────────────────────────
        *get_document_agent_tools(user_id, session_id),   # search + generate + edit doc

        # ── Email sub-agent ──────────────────────────────────────────────
        *get_email_agent_tools(user_id, session_id),      # draft + edit email

        # ── Own tools ────────────────────────────────────────────────────
        get_breakdown_task_tool(user_id, session_id),
        get_study_plan_tool(user_id, session_id),
        get_create_subtasks_tool(user_id, session_id),
        get_suggest_resources_tool(user_id, session_id),
    ]