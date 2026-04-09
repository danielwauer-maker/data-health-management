from __future__ import annotations

import json

from app.models import AdminAuditEvent
from app.services.billing_service import utc_now


def log_admin_event(
    db,
    *,
    admin_username: str,
    action: str,
    target_type: str,
    target_id: str,
    details: dict | None = None,
) -> AdminAuditEvent:
    event = AdminAuditEvent(
        admin_username=(admin_username or "").strip() or "unknown",
        action=(action or "").strip().lower(),
        target_type=(target_type or "").strip().lower(),
        target_id=(target_id or "").strip(),
        details_json=json.dumps(details or {}, ensure_ascii=True, sort_keys=True),
        created_at_utc=utc_now(),
    )
    db.add(event)
    return event
