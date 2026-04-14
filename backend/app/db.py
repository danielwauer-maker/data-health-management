import time

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.settings import settings

REQUIRED_ALEMBIC_REVISION = "0011_scan_module_scores_and_issue_category"


class Base(DeclarativeBase):
    pass


engine = create_engine(
    settings.DATABASE_URL,
    future=True,
    pool_pre_ping=True,
)

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
            print(
                f"Database not ready yet (attempt {attempt}/{max_attempts}). "
                f"Retrying in {delay_seconds}s..."
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
