# app/agents/document_agent.py

from langchain_core.tools import tool
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings
from app.db.connection import get_database
from datetime import datetime, timezone

_document_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.ORCHESTRATOR_MODEL,
    temperature=0.3,
    max_tokens=4096,
    timeout=20,
    max_retries=2,
)

async def _save_doc_pending(user_id: str, session_id: str, action: dict):
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {"$set": {
            "pending_action": action,
            "updated_at":     datetime.now(timezone.utc),
        }},
    )


def _build_document_preview(title: str, content: str, changed: bool = False) -> str:
    """
    Shows the FULL generated content in chat so the user can read it,
    request edits, or just copy it without needing a DOCX at all.

    Format:
      - Icon + title
      - Full content (the actual text)
      - Word count
      - Two options: edit OR create DOCX
    """
    word_count = len(content.split())
    icon       = "✏️ Updated" if changed else "✅ Here's your"

    return (
        f"{icon} **{title}**\n\n"
        f"{content}\n\n"                       # ← full content shown in chat
        f"─────────────────────\n"
        f"📊 {word_count} words\n\n"
        f"💬 Want any changes? Just tell me "
        f"(e.g. 'make the intro longer', 'add more examples', 'simpler language').\n"
        f"📄 Need it as a file? Say **yes** to download the DOCX!"
    )


# ── Tool 1 — Web Search ──────────────────────────────────────────────────────
def get_search_topic_tool(user_id: str, session_id: str):
    @tool
    async def search_topic_tool(query: str, max_results: int = 5) -> str:
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


# ── Tool 2 — Generate Solution ───────────────────────────────────────────────
def get_generate_solution_tool(user_id: str, session_id: str):
    @tool
    async def generate_solution_tool(
        topic: str,
        subject: str = "General",
        doc_type: str = "assignment",
        details: str = "",
    ) -> str:
        """
        Generate a complete solution for an assignment, proposal, report, or essay.
        Shows the full content in chat so user can read it, request edits,
        or download as DOCX — their choice.
        Use when user says: 'write my assignment', 'solve this', 'help me with',
        'create a solution for', 'write a proposal', 'generate a report on',
        'write an essay on', 'write my project on', 'I have an assignment on'.
        doc_type options: 'assignment', 'proposal', 'report', 'essay'
        """
        try:
            # Optional web search for reference
            search_context = ""
            try:
                from app.crud.web_search import search_web
                results = await search_web(f"{topic} {subject}", max_results=4)
                if "No web results" not in results and "error" not in results.lower():
                    search_context = f"\n\nReference material:\n{results}"
            except Exception:
                pass

            doc_prompts = {
                "assignment": f"""Write a complete, well-structured academic assignment solution.

Topic: {topic}
Subject: {subject}
Details: {details or 'Standard undergraduate level'}
{search_context}

Use # for main headings, ## for sub-headings. Required sections:
# Introduction
# Theory / Background
## Core Concepts
# Worked Examples
## Example 1
## Example 2
## Example 3
# Practice Problems
# Key Takeaways
# References

Be thorough, clear, undergraduate level. Plain text with heading markers only.""",

                "proposal": f"""Write a professional freelance project proposal.

Project: {topic}
Client/Field: {subject}
Details: {details or 'Standard professional proposal'}
{search_context}

# Project Proposal: {topic}
## Executive Summary
## Understanding of Requirements
## Proposed Solution
## Timeline
## Pricing
## About Me / Our Team
## Why Choose Us
## Next Steps

Professional, specific, confident tone.""",

                "report": f"""Write a comprehensive report.

Topic: {topic}
Field: {subject}
Details: {details or 'Standard report format'}
{search_context}

# {topic} — Report
## Abstract
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
Details: {details or 'Standard academic essay'}
{search_context}

Clear introduction, structured body paragraphs, conclusion.
Use # for section headings. Academic but readable tone.""",
            }

            prompt   = doc_prompts.get(doc_type, doc_prompts["assignment"])
            response = await _document_llm.ainvoke([
                SystemMessage(content=(
                    "You are an expert academic and professional writer. "
                    "Generate complete, high-quality content. "
                    "Use heading markers (# and ##) exactly as instructed. "
                    "Be thorough — the user will read this in chat and decide "
                    "whether to download it as a DOCX file."
                )),
                HumanMessage(content=prompt),
            ])

            content = response.content.strip()
            title   = topic if len(topic) <= 60 else topic[:57] + "..."
            
            
            # Warn (don't silently overwrite) if a different unconfirmed action
# is already pending — prevents "generate essay" then "draft email"
# from losing the essay's pending DOCX creation before the user confirms.
            db = get_database()
            existing = await db["conversations"].find_one(
                {"user_id": user_id, "session_id": session_id}, {"pending_action": 1}
            )
            existing_pending = existing.get("pending_action") if existing else None
            collision_note = ""
            if existing_pending and existing_pending.get("type") != "create_docx":
                collision_note = (
                    "⚠️ Note: this replaces your previous unconfirmed "
                    f"{existing_pending.get('type', 'action')} — say yes now to keep *this* one.\n\n"
                )

            await _save_doc_pending(user_id, session_id, {
                "type":    "create_docx",
                "title":   title,
                "content": content,
                "subject": subject,
            })

            return collision_note + _build_document_preview(title, content)

        except Exception as e:
            return f"Failed to generate solution: {str(e)}"

    return generate_solution_tool


# ── Tool 3 — Edit Document ───────────────────────────────────────────────────
def get_edit_document_tool(user_id: str, session_id: str):
    @tool
    async def edit_document_tool(edit_instruction: str) -> str:
        """
        Edit the current document draft based on the user's instruction.
        Use when user asks to change something in a document that was just generated.
        Examples: 'make the intro longer', 'add more examples', 'change tone to formal',
        'remove practice problems', 'rewrite conclusion', 'use simpler language',
        'make it shorter', 'add a summary', 'fix the examples'.
        Only call this when a document is currently being worked on.
        """
        try:
            db  = get_database()
            doc = await db["conversations"].find_one(
                {"user_id": user_id, "session_id": session_id},
                {"pending_action": 1},
            )

            if not doc or not doc.get("pending_action"):
                return "No document found to edit. Please generate a document first."

            pending = doc["pending_action"]
            if pending.get("type") != "create_docx":
                return "No document draft found. Please generate a document first."

            current_content = pending.get("content", "")
            title           = pending.get("title", "Document")

            response = await _document_llm.ainvoke([
                SystemMessage(content=(
                    "You are a precise document editor. "
                    "Apply only the requested change. "
                    "Return the COMPLETE document — never truncate or summarize."
                )),
                HumanMessage(content=f"""Edit this document. Apply ONLY the requested change.
Keep everything else exactly the same.

CURRENT DOCUMENT:
{current_content}

EDIT INSTRUCTION: {edit_instruction}

Return the COMPLETE updated document."""),
            ])

            updated = response.content.strip()

            await db["conversations"].update_one(
                {"user_id": user_id, "session_id": session_id},
                {"$set": {
                    "pending_action.content": updated,
                    "updated_at":             datetime.now(timezone.utc),
                }},
            )

            return _build_document_preview(title, updated, changed=True)

        except Exception as e:
            return f"Failed to edit document: {str(e)}"

    return edit_document_tool


def get_document_agent_tools(user_id: str, session_id: str = "") -> list:
    return [
        get_search_topic_tool(user_id, session_id),
        get_generate_solution_tool(user_id, session_id),
        get_edit_document_tool(user_id, session_id),
    ]