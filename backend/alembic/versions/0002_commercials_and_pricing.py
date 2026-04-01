"""add commercial, profile, and config schema

Revision ID: 0002_commercials_and_pricing
Revises: 0001_initial_core
Create Date: 2026-04-01 00:10:00
"""
from alembic import op
import sqlalchemy as sa

revision = "0002_commercials_and_pricing"
down_revision = "0001_initial_core"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("scans", sa.Column("total_records", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("estimated_loss_eur", sa.Float(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("potential_saving_eur", sa.Float(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("estimated_premium_price_monthly", sa.Float(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("roi_eur", sa.Float(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("customers_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("vendors_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("items_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("customer_ledger_entries_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("vendor_ledger_entries_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("item_ledger_entries_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("sales_headers_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("sales_lines_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("purchase_headers_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("purchase_lines_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("gl_entries_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("value_entries_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("scans", sa.Column("warehouse_entries_count", sa.Integer(), nullable=False, server_default="0"))

    op.add_column("scan_issues", sa.Column("estimated_impact_eur", sa.Float(), nullable=False, server_default="0"))

    op.add_column("issue_cost_config", sa.Column("title", sa.String(length=255), nullable=False, server_default=""))

    op.add_column("license_pricing_config", sa.Column("display_name", sa.String(length=80), nullable=False, server_default=""))
    op.add_column("license_pricing_config", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))

    op.create_table(
        "issue_impact_config",
        sa.Column("code", sa.String(length=80), primary_key=True),
        sa.Column("title", sa.String(length=255), nullable=False, server_default=""),
        sa.Column("category", sa.String(length=50), nullable=False, server_default="general"),
        sa.Column("minutes_per_occurrence", sa.Float(), nullable=False, server_default="5"),
        sa.Column("probability", sa.Float(), nullable=False, server_default="0.2"),
        sa.Column("frequency_per_year", sa.Float(), nullable=False, server_default="12"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    op.create_table(
        "impact_settings_config",
        sa.Column("key", sa.String(length=80), primary_key=True),
        sa.Column("value_number", sa.Float(), nullable=False, server_default="0"),
        sa.Column("title", sa.String(length=255), nullable=False, server_default=""),
    )


def downgrade() -> None:
    op.drop_table("impact_settings_config")
    op.drop_table("issue_impact_config")
    op.drop_column("license_pricing_config", "is_active")
    op.drop_column("license_pricing_config", "display_name")
    op.drop_column("issue_cost_config", "title")
    op.drop_column("scan_issues", "estimated_impact_eur")
    for column_name in [
        "warehouse_entries_count",
        "value_entries_count",
        "gl_entries_count",
        "purchase_lines_count",
        "purchase_headers_count",
        "sales_lines_count",
        "sales_headers_count",
        "item_ledger_entries_count",
        "vendor_ledger_entries_count",
        "customer_ledger_entries_count",
        "items_count",
        "vendors_count",
        "customers_count",
        "roi_eur",
        "estimated_premium_price_monthly",
        "potential_saving_eur",
        "estimated_loss_eur",
        "total_records",
    ]:
        op.drop_column("scans", column_name)
