"""add hashed tenant api token column

Revision ID: 0003_tenant_api_token_hash
Revises: 0002_commercials_and_pricing
Create Date: 2026-04-09 11:00:00
"""

from alembic import op
import sqlalchemy as sa

revision = "0003_tenant_api_token_hash"
down_revision = "0002_commercials_and_pricing"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("tenants", sa.Column("api_token_hash", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("tenants", "api_token_hash")
