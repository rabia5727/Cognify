# app/crud/email_generator.py
# Email content generation + Rabia's Gmail send placeholder
#
# BOUNDARY:
#   Taiba owns: generate_email_draft(), edit_email_draft()
#   Rabia owns: send_email_via_gmail() — she implements Gmail API here

import re
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _is_valid_email(value: str) -> bool:
    """
    True if `value` looks like an actual email address. The draft LLM is
    deliberately allowed to write a name/role as a placeholder recipient
    (e.g. "TO: Noor") when given one — this catches that before it reaches
    Gmail's API, which rejects anything that isn't address-shaped with a
    cryptic "Invalid To header" error.
    """
    return bool(_EMAIL_RE.match((value or "").strip()))

_email_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model=settings.ORCHESTRATOR_MODEL,
    temperature=0.4,
    max_tokens=1024,
    timeout=20,
    max_retries=2,
)


def _parse_email_response(content: str, fallback_to: str = "") -> dict:
    """
    Parses the structured LLM response into a clean dict.
    Expected format:
        TO: recipient
        SUBJECT: subject line
        BODY:
        body text...
    """
    lines      = content.strip().split("\n")
    to_val     = fallback_to
    subject_val = ""
    body_lines  = []
    in_body     = False

    for line in lines:
        if line.upper().startswith("TO:") and not in_body:
            to_val = line[3:].strip()
        elif line.upper().startswith("SUBJECT:") and not in_body:
            subject_val = line[8:].strip()
        elif line.upper().startswith("BODY:"):
            in_body = True
        elif in_body:
            body_lines.append(line)

    return {
        "to":      to_val,
        "subject": subject_val,
        "body":    "\n".join(body_lines).strip(),
    }


async def generate_email_draft(
    context: str,
    to: str = "",
    tone: str = "professional",
    email_type: str = "general",
) -> dict:
    """
    Generates a complete email draft from a natural language context description.

    Args:
        context:    What the email is about (e.g. "request extension for assignment")
        to:         Recipient email or role (optional — LLM suggests if blank)
        tone:       'professional' | 'formal' | 'friendly' | 'apologetic' | 'urgent'
        email_type: 'general' | 'academic' | 'freelance' | 'follow_up' | 'apology'

    Returns:
        dict with keys: to, subject, body
    """
    prompt = f"""Write a complete, well-structured email.

Purpose / Context: {context}
Recipient: {to if to else 'appropriate recipient (suggest a role/title, not a made-up email)'}
Tone: {tone}
Type: {email_type}

Return EXACTLY in this format — no extra text before or after:
TO: [recipient role or email]
SUBJECT: [clear, specific subject line]
BODY:
[Complete email — greeting, body paragraphs, professional sign-off]
[Sign off as: CoCo Assistant / Cognify User]"""

    response = await _email_llm.ainvoke([
        SystemMessage(content=(
            "You are a professional email writer. "
            "Write clear, appropriate, well-structured emails. "
            "Always follow the EXACT format requested — TO, SUBJECT, BODY labels required."
        )),
        HumanMessage(content=prompt),
    ])

    return _parse_email_response(response.content, fallback_to=to)


async def edit_email_draft(current_draft: dict, edit_instruction: str) -> dict:
    """
    Applies a targeted edit instruction to an existing email draft.
    Only changes what was asked — everything else stays the same.

    Args:
        current_draft:    dict with to, subject, body
        edit_instruction: natural language edit request

    Returns:
        updated dict with to, subject, body
    """
    prompt = f"""Edit this email based on the instruction below.
Change ONLY what is asked. Keep everything else identical.

CURRENT EMAIL:
TO: {current_draft.get('to', '')}
SUBJECT: {current_draft.get('subject', '')}
BODY:
{current_draft.get('body', '')}

EDIT INSTRUCTION: {edit_instruction}

Return EXACTLY in this format:
TO: [recipient]
SUBJECT: [subject]
BODY:
[updated body]"""

    response = await _email_llm.ainvoke([
        SystemMessage(content=(
            "You are a precise email editor. "
            "Apply only the requested change, keep everything else the same. "
            "Always return the full TO / SUBJECT / BODY structure."
        )),
        HumanMessage(content=prompt),
    ])

    return _parse_email_response(
        response.content,
        fallback_to=current_draft.get("to", ""),
    )


# ── ✅ RABIA PLUGS IN HERE ────────────────────────────────────────────────────
async def send_email_via_gmail(to: str, subject: str, body: str, user_id: str = "") -> str:
    """
    Sends an email via Gmail API using the user's connected Gmail account.

    Called from assistant.py _execute_pending_action() when:
      - action["type"] == "send_email"
      - user confirmed with "yes"
    """
    from app.db.connection import get_database
    from app.services.gmail_service import GmailService

    if not _is_valid_email(to):
        return (
            f"📧 Your email is drafted, but I don't have a real email "
            f"address for the recipient — it's currently set to \"{to}\".\n\n"
            f"**Subject:** {subject}\n\n"
            f"What's their actual email address? Once you tell me, I can send it."
        )

    db = get_database()

    try:
        await GmailService.send_email(user_id, db, to=to, subject=subject, body=body)
    except Exception as e:
        if "Gmail not connected" in str(e):
            return (
                f"📧 Your email is drafted and ready:\n\n"
                f"**To:** {to}\n**Subject:** {subject}\n\n"
                f"But your Gmail account isn't connected yet, so I can't send it "
                f"for you. Connect Gmail in Settings, then ask me to send it again — "
                f"or copy the draft above and send it manually for now."
            )
        return (
            f"📧 Your email is drafted, but sending it failed: {str(e)}\n\n"
            f"**To:** {to}\n**Subject:** {subject}\n\n"
            f"You can copy the draft above and send it manually for now."
        )

    return f"✅ Sent! Your email to **{to}** is on its way."