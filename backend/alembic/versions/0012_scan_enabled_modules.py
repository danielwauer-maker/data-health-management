"""add enabled modules to scans

Revision ID: 0012_scan_enabled_modules
Revises: 0011_scan_module_scores_and_issue_category
Create Date: 2026-04-16
"""
from alembic import op
import sqlalchemy as sa

revision = "0012_scan_enabled_modules"
down_revision = "0011_scan_module_scores_and_issue_category"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("scans") as batch_op:
        batch_op.add_column(sa.Column("enabled_modules", sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("scans") as batch_op:
        batch_op.drop_column("enabled_modules")
