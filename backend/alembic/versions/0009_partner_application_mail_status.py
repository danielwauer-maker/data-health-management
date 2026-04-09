"""partner application mail status tracking

Revision ID: 0009_partner_application_mail_status
Revises: 0008_partner_applications
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa


revision = "0009_partner_application_mail_status"
down_revision = "0008_partner_applications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "partner_applications",
        sa.Column("mail_status", sa.String(length=20), nullable=False, server_default="pending"),
    )
    op.add_column(
        "partner_applications",
        sa.Column("last_mail_error", sa.Text(), nullable=True),
    )
    op.add_column(
        "partner_applications",
        sa.Column("last_mail_sent_at_utc", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        op.f("ix_partner_applications_mail_status"),
        "partner_applications",
        ["mail_status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_partner_applications_last_mail_sent_at_utc"),
        "partner_applications",
        ["last_mail_sent_at_utc"],
        unique=False,
    )
    op.alter_column("partner_applications", "mail_status", server_default=None)


def downgrade() -> None:
    op.drop_index(op.f("ix_partner_applications_last_mail_sent_at_utc"), table_name="partner_applications")
    op.drop_index(op.f("ix_partner_applications_mail_status"), table_name="partner_applications")
    op.drop_column("partner_applications", "last_mail_sent_at_utc")
    op.drop_column("partner_applications", "last_mail_error")
    op.drop_column("partner_applications", "mail_status")
