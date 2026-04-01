"""initial core schema

Revision ID: 0001_initial_core
Revises: None
Create Date: 2026-04-01 00:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = "0001_initial_core"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tenants",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.String(length=50), nullable=False),
        sa.Column("api_token", sa.String(length=80), nullable=False),
        sa.Column("environment_name", sa.String(length=100), nullable=False),
        sa.Column("app_version", sa.String(length=30), nullable=False),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_plan", sa.String(length=20), nullable=False, server_default="free"),
        sa.Column("license_status", sa.String(length=20), nullable=False, server_default="trial"),
    )
    op.create_index("ix_tenants_id", "tenants", ["id"])
    op.create_index("ix_tenants_tenant_id", "tenants", ["tenant_id"], unique=True)
    op.create_index("ix_tenants_api_token", "tenants", ["api_token"], unique=True)
    op.create_index("ix_tenants_last_seen_at_utc", "tenants", ["last_seen_at_utc"])

    op.create_table(
        "scans",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("scan_id", sa.String(length=50), nullable=False),
        sa.Column("tenant_id", sa.String(length=50), sa.ForeignKey("tenants.tenant_id"), nullable=False),
        sa.Column("scan_type", sa.String(length=20), nullable=False),
        sa.Column("generated_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("data_score", sa.Integer(), nullable=False),
        sa.Column("checks_count", sa.Integer(), nullable=False),
        sa.Column("issues_count", sa.Integer(), nullable=False),
        sa.Column("premium_available", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("summary_headline", sa.String(length=255), nullable=False),
        sa.Column("summary_rating", sa.String(length=30), nullable=False),
    )
    op.create_index("ix_scans_id", "scans", ["id"])
    op.create_index("ix_scans_scan_id", "scans", ["scan_id"], unique=True)
    op.create_index("ix_scans_tenant_id", "scans", ["tenant_id"])
    op.create_index("ix_scans_generated_at_utc", "scans", ["generated_at_utc"])

    op.create_table(
        "scan_issues",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("scan_id", sa.String(length=50), sa.ForeignKey("scans.scan_id"), nullable=False),
        sa.Column("code", sa.String(length=80), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("severity", sa.String(length=20), nullable=False),
        sa.Column("affected_count", sa.Integer(), nullable=False),
        sa.Column("premium_only", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("recommendation_preview", sa.Text(), nullable=True),
    )
    op.create_index("ix_scan_issues_id", "scan_issues", ["id"])
    op.create_index("ix_scan_issues_scan_id", "scan_issues", ["scan_id"])
    op.create_index("ix_scan_issues_code", "scan_issues", ["code"])

    op.create_table(
        "issue_cost_config",
        sa.Column("code", sa.String(length=80), primary_key=True),
        sa.Column("cost_per_record", sa.Float(), nullable=False, server_default="10"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    op.create_table(
        "license_pricing_config",
        sa.Column("plan_code", sa.String(length=20), primary_key=True),
        sa.Column("base_price_monthly", sa.Float(), nullable=False, server_default="0"),
        sa.Column("included_records", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("additional_price_per_1000_records", sa.Float(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_table("license_pricing_config")
    op.drop_table("issue_cost_config")
    op.drop_index("ix_scan_issues_code", table_name="scan_issues")
    op.drop_index("ix_scan_issues_scan_id", table_name="scan_issues")
    op.drop_index("ix_scan_issues_id", table_name="scan_issues")
    op.drop_table("scan_issues")
    op.drop_index("ix_scans_generated_at_utc", table_name="scans")
    op.drop_index("ix_scans_tenant_id", table_name="scans")
    op.drop_index("ix_scans_scan_id", table_name="scans")
    op.drop_index("ix_scans_id", table_name="scans")
    op.drop_table("scans")
    op.drop_index("ix_tenants_last_seen_at_utc", table_name="tenants")
    op.drop_index("ix_tenants_api_token", table_name="tenants")
    op.drop_index("ix_tenants_tenant_id", table_name="tenants")
    op.drop_index("ix_tenants_id", table_name="tenants")
    op.drop_table("tenants")
