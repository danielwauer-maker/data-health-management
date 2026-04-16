from __future__ import annotations

import json
import logging
from contextvars import ContextVar
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

_request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)


def generate_request_id() -> str:
    return uuid4().hex


def set_request_id(request_id: str) -> None:
    _request_id_ctx.set(request_id)


def clear_request_id() -> None:
    _request_id_ctx.set(None)


def get_request_id() -> str | None:
    return _request_id_ctx.get()


class RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if not hasattr(record, "request_id"):
            record.request_id = get_request_id()
        if not hasattr(record, "event"):
            record.event = None
        return True


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if getattr(record, "request_id", None):
            payload["request_id"] = record.request_id
        if getattr(record, "event", None):
            payload["event"] = record.event

        reserved = {
            "args",
            "asctime",
            "created",
            "exc_info",
            "exc_text",
            "filename",
            "funcName",
            "levelname",
            "levelno",
            "lineno",
            "module",
            "msecs",
            "message",
            "msg",
            "name",
            "pathname",
            "process",
            "processName",
            "relativeCreated",
            "request_id",
            "stack_info",
            "thread",
            "threadName",
            "event",
        }
        for key, value in record.__dict__.items():
            if key in reserved or key.startswith("_"):
                continue
            if isinstance(value, (str, int, float, bool)) or value is None:
                payload[key] = value
            else:
                payload[key] = str(value)

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, ensure_ascii=True)


def configure_logging() -> None:
    root_logger = logging.getLogger()
    if getattr(root_logger, "_bcsentinel_configured", False):
        return

    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    handler.addFilter(RequestContextFilter())

    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.INFO)
    root_logger._bcsentinel_configured = True  # type: ignore[attr-defined]


def log_event(logger: logging.Logger, level: int, event: str, message: str, **fields: Any) -> None:
    logger.log(level, message, extra={"event": event, **fields})
