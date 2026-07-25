"""Email OTP authentication for Control Center (owner-only)."""

from __future__ import annotations

import hashlib
import hmac
import os
import random
import smtplib
import time
from email.message import EmailMessage
from typing import Any


def owner_email() -> str:
    return (os.getenv("DASHBOARD_OWNER_EMAIL") or "").strip().lower()


def _token_secret() -> str:
    return os.getenv("DASHBOARD_TOKEN_SECRET", (os.getenv("DASHBOARD_PASSWORD") or "astraforge") + "-secret")


def hash_owner_password(password: str) -> str:
    raw = f"owner-pass:{password}:{_token_secret()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def owner_password_configured() -> bool:
    return bool((os.getenv("DASHBOARD_OWNER_PASSWORD_HASH") or "").strip())


def verify_owner_password(password: str) -> bool:
    expected = (os.getenv("DASHBOARD_OWNER_PASSWORD_HASH") or "").strip()
    if not expected or not password:
        return False
    return hmac.compare_digest(expected, hash_owner_password(password))


def make_session_token(email: str) -> str:
    raw = f"otp-session:{email.lower()}:{_token_secret()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def valid_session_token(token: str | None, email: str | None = None) -> bool:
    if not token:
        return False
    owner = (email or owner_email()).lower()
    if not owner:
        return False
    expected = make_session_token(owner)
    return hmac.compare_digest(token, expected)


def hash_code(email: str, code: str) -> str:
    raw = f"{email.lower()}:{code}:{_token_secret()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def generate_code() -> str:
    return f"{random.randint(100000, 999999)}"


def send_otp_email(to_email: str, code: str) -> dict[str, Any]:
    """Send OTP via SMTP if configured. Returns delivery status."""
    host = os.getenv("SMTP_HOST", "").strip()
    port = int(os.getenv("SMTP_PORT", "587") or 587)
    user = os.getenv("SMTP_USER", "").strip()
    password = os.getenv("SMTP_PASS", "").strip()
    mail_from = os.getenv("SMTP_FROM", user or "astraforge@localhost").strip()
    resend_key = os.getenv("RESEND_API_KEY", "").strip()

    subject = "AstraForge код входу"
    body = (
        f"Ваш код входу в AstraForge: {code}\n\n"
        f"Код дійсний 10 хвилин.\n"
        f"Якщо це не ви — ігноруйте лист.\n"
    )

    if resend_key:
        try:
            import httpx

            r = httpx.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {resend_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": mail_from if "@" in mail_from else "AstraForge <onboarding@resend.dev>",
                    "to": [to_email],
                    "subject": subject,
                    "text": body,
                },
                timeout=20.0,
            )
            if r.status_code < 300:
                return {"ok": True, "via": "resend"}
            return {"ok": False, "via": "resend", "error": r.text[:200]}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "via": "resend", "error": str(exc)}

    if host and user and password:
        try:
            msg = EmailMessage()
            msg["Subject"] = subject
            msg["From"] = mail_from
            msg["To"] = to_email
            msg.set_content(body)
            with smtplib.SMTP(host, port, timeout=20) as smtp:
                smtp.starttls()
                smtp.login(user, password)
                smtp.send_message(msg)
            return {"ok": True, "via": "smtp"}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "via": "smtp", "error": str(exc)}

    # Dev / cloud fallback: persist to outbox file (owner still must know email allowlist)
    from pathlib import Path

    outbox = Path("data/otp_outbox.txt")
    outbox.parent.mkdir(parents=True, exist_ok=True)
    outbox.write_text(
        f"{time.strftime('%Y-%m-%d %H:%M:%S UTC')} to={to_email} code={code}\n",
        encoding="utf-8",
    )
    return {
        "ok": True,
        "via": "outbox",
        "warning": "SMTP/RESEND не налаштовано — код записано в data/otp_outbox.txt",
    }
