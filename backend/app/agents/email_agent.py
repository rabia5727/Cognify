# app/agents/email_agent.py
# Email Agent — draft and edit email tools
#
# Tools:
#   draft_email_tool  — generates a full email, shows preview,
#                       saves as pending_action type="send_email"
#   edit_email_tool   — edits the draft on user request, shows updated preview
#
# Confirmation flow (same pattern as document generation):
#   1. draft_email_tool → preview shown → "say yes to send"
#   2. User: "make it more formal" → edit_email_tool → new preview
#   3. User: "yes" → chat_with_coco confirmation check →
#      _execute_pending_action → send_email_via_gmail (Rabia)

from langchain_core.tools import tool
from app.db.connection import get_database
from datetime import datetime, timezone


# ── Helpers ──────────────────────────────────────────────────────────────────

async def _save_email_pending(user_id: str, session_id: str, email: dict):
    """Saves the email draft as pending_action on the session document."""
    db = get_database()
    await db["conversations"].update_one(
        {"user_id": user_id, "session_id": session_id},
        {"$set": {
            "pending_action": {
                "type":    "send_email",
                "to":      email.get("to", ""),
                "subject": email.get("subject", ""),
                "body":    email.get("body", ""),
            },
            "updated_at": datetime.now(timezone.utc),
        }},
    )


def _format_email_preview(email: dict, changed: bool = False) -> str:
    """
    Formats the email draft as a readable chat message.
    Shows the full email — user needs to see the whole thing
    to make meaningful edit requests.
    """
    icon = "✏️ Updated draft!" if changed else "📧 Email draft ready!"

    return (
        f"{icon}\n\n"
        f"**To:** {email.get('to', '—')}\n"
        f"**Subject:** {email.get('subject', '—')}\n\n"
        f"───────────────────\n"
        f"{email.get('body', '')}\n"
        f"───────────────────\n\n"
        f"💬 Want any changes? "
        f"(e.g. 'make it more formal', 'shorten it', 'change the subject', "
        f"'change the recipient to HR department')\n"
        f"📤 Happy with it? Say **yes** to send!"
    )


# ─────────────────────────────────────────────────────────────────────────────
# Tool 1 — Draft Email
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Tool 1 — Draft Email
# ─────────────────────────────────────────────────────────────────────────────
def get_draft_email_tool(user_id: str, session_id: str):
    @tool
    async def draft_email_tool(
        context: str,
        to: str = "",
        tone: str = "professional",
        email_type: str = "general",
    ) -> str:
        """
        Draft a complete professional email for the user.
        Shows the full email so the user can review and request edits before sending.
        Use when user says: 'write an email', 'draft an email', 'email my professor',
        'send an email to', 'compose an email', 'write a message to',
        'email my client', 'write to my supervisor'.
        tone options: 'professional', 'formal', 'friendly', 'apologetic', 'urgent'
        email_type options: 'general', 'academic', 'freelance', 'follow_up', 'apology'
        """
        try:
            from app.crud.email_generator import generate_email_draft
            
            # ✅ NEW: Check for pending_action collision before generating
            db = get_database()
            existing = await db["conversations"].find_one(
                {"user_id": user_id, "session_id": session_id}, {"pending_action": 1}
            )
            existing_pending = existing.get("pending_action") if existing else None
            collision_note = ""
            
            if existing_pending and existing_pending.get("type") != "send_email":
                collision_note = (
                    "⚠️ Note: this replaces your previous unconfirmed "
                    f"{existing_pending.get('type', 'action')} — say yes now to keep *this* one.\n\n"
                )
            
            email = await generate_email_draft(
                context=context,
                to=to,
                tone=tone,
                email_type=email_type,
            )
            
            await _save_email_pending(user_id, session_id, email)
            
            # ✅ Prepend collision warning if there was a collision
            return collision_note + _format_email_preview(email)
            
        except Exception as e:
            return f"Failed to draft email: {str(e)}"

    return draft_email_tool


# ─────────────────────────────────────────────────────────────────────────────
# Tool 2 — Edit Email Draft
# ─────────────────────────────────────────────────────────────────────────────
def get_edit_email_tool(user_id: str, session_id: str):
    @tool
    async def edit_email_tool(edit_instruction: str) -> str:
        """
        Edit the current email draft based on the user's instruction.
        Use when user asks to change something in the email being drafted.
        Examples: 'make it more formal', 'shorten it', 'change the subject',
        'add more details about the deadline', 'make the tone friendlier',
        'change recipient to the HR department', 'add an apology'.
        Only call this when an email draft is currently being worked on.
        """
        try:
            db  = get_database()
            doc = await db["conversations"].find_one(
                {"user_id": user_id, "session_id": session_id},
                {"pending_action": 1},
            )

            if not doc or not doc.get("pending_action"):
                return "No email draft found. Please draft an email first."

            pending = doc["pending_action"]
            if pending.get("type") != "send_email":
                return "No email draft found to edit. Please draft an email first."

            from app.crud.email_generator import edit_email_draft
            updated = await edit_email_draft(
                current_draft=pending,
                edit_instruction=edit_instruction,
            )

            await _save_email_pending(user_id, session_id, updated)
            return _format_email_preview(updated, changed=True)

        except Exception as e:
            return f"Failed to edit email: {str(e)}"

    return edit_email_tool


# ─────────────────────────────────────────────────────────────────────────────
# Export
# ─────────────────────────────────────────────────────────────────────────────
def get_email_agent_tools(user_id: str, session_id: str = "") -> list:
    return [
        get_draft_email_tool(user_id, session_id),
        get_edit_email_tool(user_id, session_id),
    ]