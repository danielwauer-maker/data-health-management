"""admin email templates

Revision ID: 0010_admin_email_templates
Revises: 0009_partner_application_mail_status
Create Date: 2026-04-13
"""

from alembic import op
import sqlalchemy as sa


revision = "0010_admin_email_templates"
down_revision = "0009_partner_application_mail_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_email_templates",
        sa.Column("key", sa.String(length=80), nullable=False),
        sa.Column("subject_template", sa.String(length=255), nullable=False),
        sa.Column("html_template", sa.Text(), nullable=False),
        sa.Column("updated_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("key"),
    )
    op.create_index(
        op.f("ix_admin_email_templates_updated_at_utc"),
        "admin_email_templates",
        ["updated_at_utc"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_admin_email_templates_updated_at_utc"), table_name="admin_email_templates")
    op.drop_table("admin_email_templates")
