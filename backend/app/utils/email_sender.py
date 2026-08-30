# Purpose: send transactional emails (currently: password reset OTP codes)
# from the app's own address, via Gmail SMTP + an App Password.
# This is separate from app/services/gmail_service.py, which sends mail
# through a *user's own* connected Gmail account for the AI assistant.
import asyncio
import smtplib
from email.message import EmailMessage

from app.config import settings


def _send_sync(to_email: str, subject: str, body: str) -> None:
    if not settings.SMTP_EMAIL or not settings.SMTP_APP_PASSWORD:
        raise RuntimeError(
            "SMTP_EMAIL / SMTP_APP_PASSWORD are not configured — "
            "set them in backend/.env to enable outbound email."
        )

    message = EmailMessage()
    message["From"] = settings.SMTP_EMAIL
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(body)

    with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as server:
        server.starttls()
        server.login(settings.SMTP_EMAIL, settings.SMTP_APP_PASSWORD)
        server.send_message(message)


def build_otp_email(otp_code: str) -> tuple[str, str]:
    subject = "Your Cognify password reset code"
    body = (
        f"Your Cognify verification code is: {otp_code}\n\n"
        "This code expires in 10 minutes. If you didn't request a "
        "password reset, you can safely ignore this email."
    )
    return subject, body


async def send_otp_email(to_email: str, otp_code: str) -> None:
    subject, body = build_otp_email(otp_code)
    await asyncio.to_thread(_send_sync, to_email, subject, body)
