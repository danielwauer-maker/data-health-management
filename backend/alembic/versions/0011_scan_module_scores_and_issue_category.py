"""add scan module scores and issue category

Revision ID: 0011_scan_module_scores_and_issue_category
Revises: 0010_admin_email_templates
Create Date: 2026-04-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0011_scan_module_scores_and_issue_category"
down_revision = "0010_admin_email_templates"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("scans") as batch_op:
        batch_op.add_column(sa.Column("system_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("finance_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("sales_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("purchasing_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("inventory_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("crm_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("manufacturing_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("service_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("jobs_score", sa.Integer(), nullable=False, server_default="100"))
        batch_op.add_column(sa.Column("hr_score", sa.Integer(), nullable=False, server_default="100"))

    with op.batch_alter_table("scan_issues") as batch_op:
        batch_op.add_column(sa.Column("category", sa.String(length=50), nullable=True))
        batch_op.create_index("ix_scan_issues_category", ["category"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("scan_issues") as batch_op:
        batch_op.drop_index("ix_scan_issues_category")
        batch_op.drop_column("category")

    with op.batch_alter_table("scans") as batch_op:
        batch_op.drop_column("hr_score")
        batch_op.drop_column("jobs_score")
        batch_op.drop_column("service_score")
        batch_op.drop_column("manufacturing_score")
        batch_op.drop_column("crm_score")
        batch_op.drop_column("inventory_score")
        batch_op.drop_column("purchasing_score")
        batch_op.drop_column("sales_score")
        batch_op.drop_column("finance_score")
        batch_op.drop_column("system_score")
