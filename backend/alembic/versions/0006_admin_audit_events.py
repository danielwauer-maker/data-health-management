"""admin audit events

Revision ID: 0006_admin_audit_events
Revises: 0005_partner_program_foundation
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_admin_audit_events"
down_revision = "0005_partner_program_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_audit_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("admin_username", sa.String(length=120), nullable=False),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("target_type", sa.String(length=60), nullable=False),
        sa.Column("target_id", sa.String(length=120), nullable=False),
        sa.Column("details_json", sa.Text(), nullable=False),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_admin_audit_events_id"), "admin_audit_events", ["id"], unique=False)
    op.create_index(
        op.f("ix_admin_audit_events_admin_username"),
        "admin_audit_events",
        ["admin_username"],
        unique=False,
    )
    op.create_index(op.f("ix_admin_audit_events_action"), "admin_audit_events", ["action"], unique=False)
    op.create_index(
        op.f("ix_admin_audit_events_target_type"),
        "admin_audit_events",
        ["target_type"],
        unique=False,
    )
    op.create_index(op.f("ix_admin_audit_events_target_id"), "admin_audit_events", ["target_id"], unique=False)
    op.create_index(
        op.f("ix_admin_audit_events_created_at_utc"),
        "admin_audit_events",
        ["created_at_utc"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_admin_audit_events_created_at_utc"), table_name="admin_audit_events")
    op.drop_index(op.f("ix_admin_audit_events_target_id"), table_name="admin_audit_events")
    op.drop_index(op.f("ix_admin_audit_events_target_type"), table_name="admin_audit_events")
    op.drop_index(op.f("ix_admin_audit_events_action"), table_name="admin_audit_events")
    op.drop_index(op.f("ix_admin_audit_events_admin_username"), table_name="admin_audit_events")
    op.drop_index(op.f("ix_admin_audit_events_id"), table_name="admin_audit_events")
    op.drop_table("admin_audit_events")
