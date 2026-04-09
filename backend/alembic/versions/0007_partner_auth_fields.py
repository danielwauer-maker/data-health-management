"""partner auth fields

Revision ID: 0007_partner_auth_fields
Revises: 0006_admin_audit_events
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa


revision = "0007_partner_auth_fields"
down_revision = "0006_admin_audit_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("partners", sa.Column("contact_email", sa.String(length=255), nullable=True))
    op.add_column("partners", sa.Column("password_hash", sa.String(length=255), nullable=True))
    op.add_column("partners", sa.Column("last_login_at_utc", sa.DateTime(timezone=True), nullable=True))
    op.create_index(op.f("ix_partners_contact_email"), "partners", ["contact_email"], unique=True)
    op.create_index(op.f("ix_partners_last_login_at_utc"), "partners", ["last_login_at_utc"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_partners_last_login_at_utc"), table_name="partners")
    op.drop_index(op.f("ix_partners_contact_email"), table_name="partners")
    op.drop_column("partners", "last_login_at_utc")
    op.drop_column("partners", "password_hash")
    op.drop_column("partners", "contact_email")
