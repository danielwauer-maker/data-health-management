import time
import logging

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.settings import settings

REQUIRED_ALEMBIC_REVISION = "0012_scan_enabled_modules"
logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    pass


engine_kwargs = {
    "future": True,
    "pool_pre_ping": True,
}

if settings.DATABASE_URL.startswith("sqlite"):
    engine_kwargs["connect_args"] = {"check_same_thread": False}

engine = create_engine(settings.DATABASE_URL, **engine_kwargs)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    future=True,
)


def wait_for_database(max_attempts: int = 30, delay_seconds: int = 2) -> None:
    last_error: Exception | None = None

    for attempt in range(1, max_attempts + 1):
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))
                return
        except OperationalError as exc:
            last_error = exc
            logger.warning(
                "Database not ready yet. Retrying.",
                extra={
                    "event": "database_wait_retry",
                    "attempt": attempt,
                    "max_attempts": max_attempts,
                    "delay_seconds": delay_seconds,
                },
            )
            time.sleep(delay_seconds)

    raise RuntimeError("Database did not become ready in time.") from last_error


def ensure_schema_is_migrated(required_revision: str = REQUIRED_ALEMBIC_REVISION) -> None:
    inspector = inspect(engine)

    if "alembic_version" not in inspector.get_table_names():
        raise RuntimeError(
            "Database schema is not managed by Alembic yet. "
            "Run 'alembic upgrade head' for a fresh database or "
            "'alembic stamp 0002_commercials_and_pricing' once for an existing database "
            "that already matches the current schema."
        )

    with engine.connect() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version LIMIT 1")).scalar()

    if version != required_revision:
        raise RuntimeError(
            f"Database schema revision mismatch. Expected '{required_revision}', got '{version}'. "
            "Run the pending Alembic migrations before starting the API."
        )
