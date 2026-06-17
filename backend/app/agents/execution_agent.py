# app/agents/execution_agent.py
# Execution Agent — Helps users actually DO their tasks

from langchain_core.tools import tool
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings
from app.db.connection import get_database
from app.models.task import TaskCreate
from app.crud.task import create_task
from datetime import datetime, timezone, timedelta


_execution_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.1-8b-instant",
    temperature=0.4,
    max_tokens=1024,
)


# ─────────────────────────────────────────────────────────────────
# Tool 1 — Breakdown Task
# ─────────────────────────────────────────────────────────────────
def get_breakdown_task_tool(user_id: str):
    @tool
    async def breakdown_task(
        task_title: str,
        task_type: str = "general",
        available_hours: float = 2.0,
    ) -> str:
        """
        Break down a complex task into actionable steps.
        Use when user says: 'help me with', 'how do I do',
        'break down task', 'I have an assignment on',
        'help me plan', 'I need to work on', 'guide me through'.
        """
        try:
            prompt = f"""Break down this task into clear, actionable steps in {available_hours} hours.

Task: {task_title}
Type: {task_type}

Return:
1. Brief overview
2. 3-6 steps with time estimates
3. Motivational closing

Plain text only, no markdown."""
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a productivity assistant. Be concise."),
                HumanMessage(content=prompt)
            ])
            return response.content.strip()
        except Exception as e:
            return f"Failed to breakdown task: {str(e)}"
    return breakdown_task


# ─────────────────────────────────────────────────────────────────
# Tool 2 — Build Study Plan
# ─────────────────────────────────────────────────────────────────
def get_study_plan_tool(user_id: str):
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
            prompt = f"""Create a focused study plan for:
Subject: {subject}
Topics: {topics}
Due: {due_date}
Time: {available_hours} hours

Include:
1. Study order
2. Time per topic (minutes)
3. Specific actions
4. Quick review tips

Plain text only."""
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a study planning assistant."),
                HumanMessage(content=prompt)
            ])
            return f"📚 Study Plan for {subject}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to build study plan: {str(e)}"
    return build_study_plan


# ─────────────────────────────────────────────────────────────────
# Tool 3 — Create Subtasks
# ─────────────────────────────────────────────────────────────────
def get_create_subtasks_tool(user_id: str):
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
            if due_date:
                now = datetime.now(timezone.utc)
                if due_date.lower() == "tomorrow":
                    parsed_due = (now + timedelta(days=1)).replace(hour=23, minute=59, second=0, microsecond=0)

            created = []
            for title in titles:
                task_data = TaskCreate(
                    title=title,
                    description=f"Subtask of: {parent_task_title}",
                    priority="medium",
                    category="general",
                    due_date=parsed_due,
                    source="manual",
                )
                task = await create_task(task_data, user_id)
                created.append(task.title)

            return f"Created {len(created)} subtasks for '{parent_task_title}':\n" + "\n".join(f"• {t}" for t in created)
        except Exception as e:
            return f"Failed to create subtasks: {str(e)}"
    return create_subtasks


# ─────────────────────────────────────────────────────────────────
# Tool 4 — Suggest Resources
# ─────────────────────────────────────────────────────────────────
def get_suggest_resources_tool(user_id: str):
    @tool
    async def suggest_resources(topic: str, level: str = "undergraduate") -> str:
        """
        Suggest learning resources and approaches for a topic.
        Use when user says: 'how do I learn', 'resources for',
        'where to start with', 'tips for studying', 'help me understand'.
        """
        try:
            prompt = f"""Suggest practical learning resources for:
Topic: {topic}
Level: {level}

Include:
1. Best approach
2. 2-3 resource types
3. Key concepts to focus on
4. Common mistakes to avoid

Plain text only."""
            response = await _execution_llm.ainvoke([
                SystemMessage(content="You are CoCo, a helpful study assistant."),
                HumanMessage(content=prompt)
            ])
            return f"💡 Resources for {topic}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to suggest resources: {str(e)}"
    return suggest_resources


# ─────────────────────────────────────────────────────────────────
# Export all Execution Agent tools
# ─────────────────────────────────────────────────────────────────
def get_execution_agent_tools(user_id: str) -> list:
    return [
        get_breakdown_task_tool(user_id),
        get_study_plan_tool(user_id),
        get_create_subtasks_tool(user_id),
        get_suggest_resources_tool(user_id),
    ]