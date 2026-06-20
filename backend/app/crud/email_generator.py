# app/crud/email_generator.py
# Email content generation + Rabia's Gmail send placeholder
#
# BOUNDARY:
#   Taiba owns: generate_email_draft(), edit_email_draft()
#   Rabia owns: send_email_via_gmail() — she implements Gmail API here

from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage
from app.config import settings

_email_llm = ChatGroq(
    api_key=settings.GROQ_API_KEY,
    model="llama-3.3-70b-versatile",
    temperature=0.4,
    max_tokens=1024,
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
    Sends an email via Gmail API.

    ┌─────────────────────────────────────────────────────┐
    │  RABIA — implement this function                    │
    │                                                     │
    │  Steps:                                             │
    │  1. Get user's Gmail OAuth token from DB            │
    │     (user_id is provided)                           │
    │  2. Build Gmail API service with the token          │
    │  3. Create message:                                 │
    │       import base64                                 │
    │       from email.mime.text import MIMEText          │
    │       msg = MIMEText(body)                          │
    │       msg['to'] = to                                │
    │       msg['subject'] = subject                      │
    │       raw = base64.urlsafe_b64encode(               │
    │                 msg.as_bytes()).decode()             │
    │  4. Send:                                           │
    │       service.users().messages().send(              │
    │           userId='me',                              │
    │           body={'raw': raw}                         │
    │       ).execute()                                   │
    │  5. Return success string                           │
    └─────────────────────────────────────────────────────┘

    This function is called from assistant.py
    _execute_pending_action() when:
      - action["type"] == "send_email"
      - user confirmed with "yes"
    """
    # TODO: Rabia replaces this placeholder with real Gmail API call
    return (
        f"📧 Email is ready to send!\n\n"
        f"**To:** {to}\n"
        f"**Subject:** {subject}\n\n"
        f"_(Gmail send integration — Rabia implementing)_\n"
        f"You can copy the email above and send it manually for now."
    )