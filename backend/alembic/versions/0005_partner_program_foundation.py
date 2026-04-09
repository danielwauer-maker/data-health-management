"""partner program foundation

Revision ID: 0005_partner_program_foundation
Revises: 0004_billing_foundation
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_partner_program_foundation"
down_revision = "0004_billing_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "partners",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("partner_code", sa.String(length=40), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("default_commission_rate", sa.Float(), nullable=False),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_partners_id"), "partners", ["id"], unique=False)
    op.create_index(op.f("ix_partners_partner_code"), "partners", ["partner_code"], unique=True)
    op.create_index(op.f("ix_partners_status"), "partners", ["status"], unique=False)

    op.create_table(
        "partner_referrals",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("partner_id", sa.Integer(), nullable=False),
        sa.Column("tenant_id", sa.String(length=50), nullable=False),
        sa.Column("referral_code", sa.String(length=80), nullable=False),
        sa.Column("attribution_source", sa.String(length=80), nullable=False),
        sa.Column("attributed_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["partner_id"], ["partners.id"], ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.tenant_id"], ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("tenant_id"),
    )
    op.create_index(op.f("ix_partner_referrals_id"), "partner_referrals", ["id"], unique=False)
    op.create_index(op.f("ix_partner_referrals_partner_id"), "partner_referrals", ["partner_id"], unique=False)
    op.create_index(op.f("ix_partner_referrals_referral_code"), "partner_referrals", ["referral_code"], unique=False)
    op.create_index(op.f("ix_partner_referrals_tenant_id"), "partner_referrals", ["tenant_id"], unique=True)

    op.create_table(
        "partner_commissions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("partner_id", sa.Integer(), nullable=False),
        sa.Column("tenant_id", sa.String(length=50), nullable=False),
        sa.Column("invoice_id", sa.Integer(), nullable=True),
        sa.Column("provider_invoice_id", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("currency", sa.String(length=10), nullable=False),
        sa.Column("base_amount", sa.Float(), nullable=False),
        sa.Column("commission_rate", sa.Float(), nullable=False),
        sa.Column("commission_amount", sa.Float(), nullable=False),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("approved_at_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paid_at_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["invoice_id"], ["invoices.id"], ),
        sa.ForeignKeyConstraint(["partner_id"], ["partners.id"], ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.tenant_id"], ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider_invoice_id"),
    )
    op.create_index(op.f("ix_partner_commissions_id"), "partner_commissions", ["id"], unique=False)
    op.create_index(op.f("ix_partner_commissions_invoice_id"), "partner_commissions", ["invoice_id"], unique=False)
    op.create_index(op.f("ix_partner_commissions_partner_id"), "partner_commissions", ["partner_id"], unique=False)
    op.create_index(
        op.f("ix_partner_commissions_provider_invoice_id"),
        "partner_commissions",
        ["provider_invoice_id"],
        unique=True,
    )
    op.create_index(op.f("ix_partner_commissions_status"), "partner_commissions", ["status"], unique=False)
    op.create_index(op.f("ix_partner_commissions_tenant_id"), "partner_commissions", ["tenant_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_partner_commissions_tenant_id"), table_name="partner_commissions")
    op.drop_index(op.f("ix_partner_commissions_status"), table_name="partner_commissions")
    op.drop_index(op.f("ix_partner_commissions_provider_invoice_id"), table_name="partner_commissions")
    op.drop_index(op.f("ix_partner_commissions_partner_id"), table_name="partner_commissions")
    op.drop_index(op.f("ix_partner_commissions_invoice_id"), table_name="partner_commissions")
    op.drop_index(op.f("ix_partner_commissions_id"), table_name="partner_commissions")
    op.drop_table("partner_commissions")

    op.drop_index(op.f("ix_partner_referrals_tenant_id"), table_name="partner_referrals")
    op.drop_index(op.f("ix_partner_referrals_referral_code"), table_name="partner_referrals")
    op.drop_index(op.f("ix_partner_referrals_partner_id"), table_name="partner_referrals")
    op.drop_index(op.f("ix_partner_referrals_id"), table_name="partner_referrals")
    op.drop_table("partner_referrals")

    op.drop_index(op.f("ix_partners_status"), table_name="partners")
    op.drop_index(op.f("ix_partners_partner_code"), table_name="partners")
    op.drop_index(op.f("ix_partners_id"), table_name="partners")
    op.drop_table("partners")
