"""add billing foundation schema

Revision ID: 0004_billing_foundation
Revises: 0003_tenant_api_token_hash
Create Date: 2026-04-09 12:00:00
"""

from alembic import op
import sqlalchemy as sa

revision = "0004_billing_foundation"
down_revision = "0003_tenant_api_token_hash"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.String(length=50), sa.ForeignKey("tenants.tenant_id"), nullable=False),
        sa.Column("provider", sa.String(length=30), nullable=False, server_default="manual"),
        sa.Column("provider_subscription_id", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="incomplete"),
        sa.Column("plan_code", sa.String(length=20), nullable=False, server_default="premium"),
        sa.Column("currency", sa.String(length=10), nullable=False, server_default="EUR"),
        sa.Column("amount_monthly", sa.Float(), nullable=False, server_default="0"),
        sa.Column("current_period_start_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_period_end_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_at_period_end", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("canceled_at_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at_utc", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_subscriptions_id", "subscriptions", ["id"])
    op.create_index("ix_subscriptions_tenant_id", "subscriptions", ["tenant_id"])
    op.create_index("ix_subscriptions_provider", "subscriptions", ["provider"])
    op.create_index("ix_subscriptions_provider_subscription_id", "subscriptions", ["provider_subscription_id"], unique=True)
    op.create_index("ix_subscriptions_status", "subscriptions", ["status"])

    op.create_table(
        "invoices",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.String(length=50), sa.ForeignKey("tenants.tenant_id"), nullable=False),
        sa.Column("provider", sa.String(length=30), nullable=False, server_default="manual"),
        sa.Column("provider_invoice_id", sa.String(length=120), nullable=False),
        sa.Column("provider_subscription_id", sa.String(length=120), nullable=True),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="open"),
        sa.Column("currency", sa.String(length=10), nullable=False, server_default="EUR"),
        sa.Column("amount_total", sa.Float(), nullable=False, server_default="0"),
        sa.Column("amount_paid", sa.Float(), nullable=False, server_default="0"),
        sa.Column("hosted_invoice_url", sa.String(length=500), nullable=True),
        sa.Column("paid_at_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_invoices_id", "invoices", ["id"])
    op.create_index("ix_invoices_tenant_id", "invoices", ["tenant_id"])
    op.create_index("ix_invoices_provider", "invoices", ["provider"])
    op.create_index("ix_invoices_provider_invoice_id", "invoices", ["provider_invoice_id"], unique=True)
    op.create_index("ix_invoices_provider_subscription_id", "invoices", ["provider_subscription_id"])
    op.create_index("ix_invoices_status", "invoices", ["status"])

    op.create_table(
        "billing_webhook_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("event_id", sa.String(length=120), nullable=False),
        sa.Column("event_type", sa.String(length=120), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column("received_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("processed_at_utc", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_billing_webhook_events_id", "billing_webhook_events", ["id"])
    op.create_index("ix_billing_webhook_events_provider", "billing_webhook_events", ["provider"])
    op.create_index("ix_billing_webhook_events_event_id", "billing_webhook_events", ["event_id"], unique=True)
    op.create_index("ix_billing_webhook_events_event_type", "billing_webhook_events", ["event_type"])


def downgrade() -> None:
    op.drop_index("ix_billing_webhook_events_event_type", table_name="billing_webhook_events")
    op.drop_index("ix_billing_webhook_events_event_id", table_name="billing_webhook_events")
    op.drop_index("ix_billing_webhook_events_provider", table_name="billing_webhook_events")
    op.drop_index("ix_billing_webhook_events_id", table_name="billing_webhook_events")
    op.drop_table("billing_webhook_events")

    op.drop_index("ix_invoices_status", table_name="invoices")
    op.drop_index("ix_invoices_provider_subscription_id", table_name="invoices")
    op.drop_index("ix_invoices_provider_invoice_id", table_name="invoices")
    op.drop_index("ix_invoices_provider", table_name="invoices")
    op.drop_index("ix_invoices_tenant_id", table_name="invoices")
    op.drop_index("ix_invoices_id", table_name="invoices")
    op.drop_table("invoices")

    op.drop_index("ix_subscriptions_status", table_name="subscriptions")
    op.drop_index("ix_subscriptions_provider_subscription_id", table_name="subscriptions")
    op.drop_index("ix_subscriptions_provider", table_name="subscriptions")
    op.drop_index("ix_subscriptions_tenant_id", table_name="subscriptions")
    op.drop_index("ix_subscriptions_id", table_name="subscriptions")
    op.drop_table("subscriptions")
