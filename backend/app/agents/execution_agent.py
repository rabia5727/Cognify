# app/agents/execution_agent.py
# Execution Agent — Helps users actually DO their tasks
#
# ✅ NEW TOOLS ADDED (2):
#   search_topic_tool       — free DuckDuckGo web search
#   generate_solution_tool  — AI writes a full solution + saves as
#                             pending_action so user confirms before
#                             a DOCX is created (confirm-before-execute)
#
# HOW confirm-before-execute WORKS:
#   1. LLM calls generate_solution_tool → content generated → saved to
#      MongoDB as pending_action on the session document → tool returns
#      a short preview + "say yes to create the DOCX"
#   2. User replies "yes" / "go ahead" / "create it"
#   3. chat_with_coco() detects confirmation + pending_action in DB →
#      calls _execute_pending_action() → creates .docx → returns
#      download link with [FILE:filename] tag for Flutter to parse
#
# ✅ SIGNATURE CHANGE:
#   get_execution_agent_tools(user_id, session_id)
#   — session_id is needed so the new tools can save pending_action
#     to the right conversation document in MongoDB.

from langchain_core.tools import tool
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings
from app.db.connection import get_database
from app.models.task import TaskCreate
from app.crud.task import create_task
from datetime import datetime, timezone, timedelta


# ── LLMs ────────────────────────────────────────────────────────────────────

_execution_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.1-8b-instant",
    temperature=0.4,
    max_tokens=1024,
)

# 70b for document generation — needs more reasoning + higher token limit
_document_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.3,
    max_tokens=4096,   # full assignments need more tokens
)


# ── Pending action helpers ───────────────────────────────────────────────────

async def _save_pending_action(user_id: str, session_id: str, action: dict):
    """
    Stores an action that needs user confirmation before executing.
    Saved on the session document so it survives across turns.
    action = {
        "type": "create_docx",
        "title": "...",
        "content": "...",
        "subject": "..."
    }
    """
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {
            "$set": {
                "pending_action": action,
                "updated_at": datetime.now(timezone.utc),
            }
        },
    )


# ─────────────────────────────────────────────────────────────────────────────
# ✅ NEW Tool 1 — Web Search (DuckDuckGo, free, no key)
# ─────────────────────────────────────────────────────────────────────────────
def get_search_topic_tool(user_id: str, session_id: str):
    @tool
    async def search_topic_tool(
        query: str,
        max_results: int = 5,
    ) -> str:
        """
        Search the web for information on any topic using DuckDuckGo.
        Use when user asks: 'search for', 'look up', 'find information about',
        'what is', 'explain', 'research', or needs real-world facts.
        Returns top search results with titles, snippets, and source links.
        """
        try:
            from app.crud.web_search import search_web
            results = await search_web(query, max_results=max_results)
            return f"🔍 Search results for '{query}':\n\n{results}"
        except Exception as e:
            return f"Search failed: {str(e)}"

    return search_topic_tool


# ─────────────────────────────────────────────────────────────────────────────
# ✅ NEW Tool 2 — Generate Solution + Save Pending Action
# ─────────────────────────────────────────────────────────────────────────────
def get_generate_solution_tool(user_id: str, session_id: str):
    @tool
    async def generate_solution_tool(
        topic: str,
        subject: str = "General",
        doc_type: str = "assignment",
        details: str = "",
    ) -> str:
        """
        Generate a complete, detailed solution for an assignment, project,
        proposal, or report — then offer to save it as a downloadable DOCX.
        Use when user says: 'write my assignment', 'solve this', 'create a
        solution for', 'write a proposal for', 'help me complete', 'generate
        a report on', 'write my project on'.
        doc_type options: 'assignment', 'proposal', 'report', 'essay'
        Always call this to generate AND offer to save as DOCX in one step.
        """
        try:
            # ── Step 1: Search for reference material ────────────────────
            search_context = ""
            try:
                from app.crud.web_search import search_web
                search_results = await search_web(f"{topic} {subject}", max_results=4)
                if "No web results" not in search_results and "error" not in search_results.lower():
                    search_context = f"\n\nUse these web search results as reference:\n{search_results}"
            except Exception:
                pass   # no search — LLM uses its own knowledge

            # ── Step 2: Generate the full solution ───────────────────────
            doc_prompts = {
                "assignment": f"""Write a complete, well-structured academic assignment solution.

Topic: {topic}
Subject: {subject}
Additional details: {details if details else 'Standard undergraduate level'}
{search_context}

Structure the document with these sections (use # for main headings, ## for sub-headings):
# Introduction
(Brief overview of the topic)

# Theory / Background
(Key concepts, formulas, definitions)

## Core Concepts
(Explain the main ideas clearly)

# Worked Examples
(3-5 step-by-step solved examples with full working shown)

## Example 1
(Complete solution with each step numbered)

# Practice Problems
(2-3 problems for the student to try, with answers)

# Key Takeaways
(Summary of the most important points)

# References
(List 3-5 relevant academic sources)

Write at undergraduate level. Be thorough but clear. Use plain text with the heading markers shown above.""",

                "proposal": f"""Write a professional freelance project proposal.

Project: {topic}
Client/Field: {subject}
Details: {details if details else 'Standard professional proposal'}
{search_context}

Structure:
# Project Proposal: {topic}

## Executive Summary
(2-3 sentence overview)

## Understanding of Requirements
(What you will deliver)

## Proposed Solution
(Your approach and methodology)

## Timeline
(Week-by-week breakdown)

## Pricing
(Clear breakdown of costs)

## About Me / Our Team
(Relevant experience)

## Why Choose Us
(Key differentiators)

## Next Steps
(Call to action)

Professional tone. Be specific and confident.""",

                "report": f"""Write a comprehensive report on the given topic.

Topic: {topic}
Field: {subject}
Details: {details if details else 'Standard report format'}
{search_context}

Structure:
# {topic} — Report

## Abstract
(100-word summary)

# 1. Introduction
# 2. Background & Literature
# 3. Main Findings / Analysis
# 4. Discussion
# 5. Conclusion
# References

Academic tone, well-structured, thorough.""",

                "essay": f"""Write a complete academic essay.

Topic: {topic}
Subject: {subject}
Details: {details if details else 'Standard academic essay'}
{search_context}

Structure with clear introduction, body paragraphs, and conclusion.
Use # for section headings. Academic but readable tone.""",
            }

            prompt = doc_prompts.get(doc_type, doc_prompts["assignment"])

            response = await _document_llm.ainvoke([
                SystemMessage(content="You are an expert academic and professional writer. "
                              "Generate complete, high-quality content. "
                              "Use the heading markers (# and ##) exactly as instructed. "
                              "Be thorough — this will be formatted into a real document."),
                HumanMessage(content=prompt),
            ])

            generated_content = response.content.strip()

            # ── Step 3: Save as pending_action ───────────────────────────
            # Content is too large to pass back as a tool arg on confirmation,
            # so we store it in MongoDB and retrieve it when user says yes.
            title = f"{topic}" if len(topic) <= 60 else topic[:57] + "..."
            await _save_pending_action(
                user_id=user_id,
                session_id=session_id,
                action={
                    "type":    "create_docx",
                    "title":   title,
                    "content": generated_content,
                    "subject": subject,
                },
            )

            # ── Step 4: Return preview + confirmation prompt ──────────────
            preview_lines = [
                ln for ln in generated_content.split("\n")
                if ln.strip() and not ln.strip().startswith("#")
            ]
            preview = " ".join(preview_lines[:3])[:300] + "..."

            doc_type_label = {
                "assignment": "assignment solution",
                "proposal":   "project proposal",
                "report":     "report",
                "essay":      "essay",
            }.get(doc_type, "document")

            return (
                f"✅ I've written a complete {doc_type_label} for '{topic}'.\n\n"
                f"**Preview:**\n{preview}\n\n"
                f"📄 Ready to create your DOCX file — just say **yes** to download it!"
            )

        except Exception as e:
            return f"Failed to generate solution: {str(e)}"

    return generate_solution_tool


# ─────────────────────────────────────────────────────────────────────────────
# Original Tool 1 — Breakdown Task (unchanged)
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
                HumanMessage(content=prompt),
            ])
            return response.content.strip()
        except Exception as e:
            return f"Failed to breakdown task: {str(e)}"

    return breakdown_task


# ─────────────────────────────────────────────────────────────────────────────
# Original Tool 2 — Build Study Plan (unchanged)
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
                HumanMessage(content=prompt),
            ])
            return f"📚 Study Plan for {subject}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to build study plan: {str(e)}"

    return build_study_plan


# ─────────────────────────────────────────────────────────────────────────────
# Original Tool 3 — Create Subtasks (unchanged)
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
            if due_date:
                now = datetime.now(timezone.utc)
                if due_date.lower() == "tomorrow":
                    parsed_due = (now + timedelta(days=1)).replace(
                        hour=23, minute=59, second=0, microsecond=0
                    )

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

            return (
                f"Created {len(created)} subtasks for '{parent_task_title}':\n"
                + "\n".join(f"• {t}" for t in created)
            )
        except Exception as e:
            return f"Failed to create subtasks: {str(e)}"

    return create_subtasks


# ─────────────────────────────────────────────────────────────────────────────
# Original Tool 4 — Suggest Resources (unchanged)
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
                HumanMessage(content=prompt),
            ])
            return f"💡 Resources for {topic}:\n\n{response.content.strip()}"
        except Exception as e:
            return f"Failed to suggest resources: {str(e)}"

    return suggest_resources


# ─────────────────────────────────────────────────────────────────────────────
# ✅ UPDATED: now requires session_id (needed by new tools)
# ─────────────────────────────────────────────────────────────────────────────
def get_execution_agent_tools(user_id: str, session_id: str = "") -> list:
    return [
        get_search_topic_tool(user_id, session_id),
        get_generate_solution_tool(user_id, session_id),
        get_breakdown_task_tool(user_id, session_id),
        get_study_plan_tool(user_id, session_id),
        get_create_subtasks_tool(user_id, session_id),
        get_suggest_resources_tool(user_id, session_id),
    ]