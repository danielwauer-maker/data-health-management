from __future__ import annotations

import re
from collections.abc import Mapping

from sqlalchemy import select

from app.models import AdminEmailTemplate
from app.services.billing_service import utc_now

PLACEHOLDER_PATTERN = re.compile(r"{{\s*([a-zA-Z0-9_]+)\s*}}")

DEFAULT_ADMIN_EMAIL_TEMPLATES: dict[str, dict[str, object]] = {
    "partner_access_invite": {
        "label": "Partner access invite",
        "description": "Wird versendet, wenn eine Partner-Bewerbung im Admin auf accepted gesetzt wird.",
        "placeholders": ["contact_name", "reset_url"],
        "subject": "Your BCSentinel partner access is ready",
        "html": """
<html>
  <body style="font-family: Arial, sans-serif; color: #1f2a44;">
    <p>Hello {{ contact_name }},</p>
    <p>your partner application has been approved.</p>
    <p>Please set your password using this secure link:</p>
    <p><a href="{{ reset_url }}">{{ reset_url }}</a></p>
    <p>After setting your password, you can log in to the partner portal.</p>
  </body>
</html>
""".strip(),
    },
    "partner_reset_request": {
        "label": "Partner password reset",
        "description": "Wird bei Passwort-vergessen an aktive Partner versendet.",
        "placeholders": ["reset_url"],
        "subject": "Reset your BCSentinel partner password",
        "html": """
<html>
  <body style="font-family: Arial, sans-serif; color: #1f2a44;">
    <p>Hello,</p>
    <p>we received a request to reset your BCSentinel partner password.</p>
    <p><a href="{{ reset_url }}">Reset password</a></p>
    <p>If you did not request this, you can ignore this email.</p>
    <p>Link expires automatically.</p>
  </body>
</html>
""".strip(),
    },
    "partner_application_received": {
        "label": "Partner registration received",
        "description": "Wird direkt nach der öffentlichen Partner-Registrierung versendet.",
        "placeholders": ["contact_name"],
        "subject": "We received your BCSentinel partner application",
        "html": """
<html>
  <body style="font-family: Arial, sans-serif; color: #1f2a44;">
    <p>Hello {{ contact_name }},</p>
    <p>thank you for your partner registration at BCSentinel.</p>
    <p>We will review your application and send your portal access as soon as it is approved.</p>
  </body>
</html>
""".strip(),
    },
}


def ensure_default_email_templates(db) -> None:
    existing = {row.key: row for row in db.scalars(select(AdminEmailTemplate)).all()}
    changed = False
    for key, default in DEFAULT_ADMIN_EMAIL_TEMPLATES.items():
        if key in existing:
            continue
        db.add(
            AdminEmailTemplate(
                key=key,
                subject_template=str(default["subject"]),
                html_template=str(default["html"]),
                updated_at_utc=utc_now(),
            )
        )
        changed = True
    if changed:
        db.commit()


def list_email_templates_for_admin(db) -> list[dict[str, object]]:
    ensure_default_email_templates(db)
    rows = {
        row.key: row
        for row in db.scalars(select(AdminEmailTemplate).order_by(AdminEmailTemplate.key.asc())).all()
    }
    result: list[dict[str, object]] = []
    for key, meta in DEFAULT_ADMIN_EMAIL_TEMPLATES.items():
        row = rows[key]
        result.append(
            {
                "key": key,
                "label": meta["label"],
                "description": meta["description"],
                "placeholders": list(meta["placeholders"]),
                "subject_template": row.subject_template,
                "html_template": row.html_template,
                "updated_at_utc": row.updated_at_utc,
            }
        )
    return result


def update_email_template(db, *, key: str, subject_template: str, html_template: str) -> AdminEmailTemplate:
    ensure_default_email_templates(db)
    row = db.get(AdminEmailTemplate, key)
    if row is None:
        raise KeyError(key)
    row.subject_template = subject_template.strip()
    row.html_template = html_template.strip()
    row.updated_at_utc = utc_now()
    db.commit()
    db.refresh(row)
    return row


def render_email_template(db, key: str, context: Mapping[str, object] | None = None) -> tuple[str, str]:
    ensure_default_email_templates(db)
    row = db.get(AdminEmailTemplate, key)
    if row is None:
        raise KeyError(key)
    return render_email_template_preview(
        subject_template=row.subject_template,
        html_template=row.html_template,
        context=context,
    )


def render_email_template_preview(
    *,
    subject_template: str,
    html_template: str,
    context: Mapping[str, object] | None = None,
) -> tuple[str, str]:
    values = {str(k): "" if v is None else str(v) for k, v in (context or {}).items()}

    def render(value: str) -> str:
        return PLACEHOLDER_PATTERN.sub(lambda match: values.get(match.group(1), ""), value or "")

    return render(subject_template), render(html_template)
