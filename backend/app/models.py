from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    tenant_id: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    api_token: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    api_token_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    environment_name: Mapped[str] = mapped_column(String(100))
    app_version: Mapped[str] = mapped_column(String(30))
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_seen_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    current_plan: Mapped[str] = mapped_column(String(20), default="free")
    license_status: Mapped[str] = mapped_column(String(20), default="trial")

    scans: Mapped[list["Scan"]] = relationship(
        back_populates="tenant",
        cascade="all, delete-orphan",
    )
    subscriptions: Mapped[list["Subscription"]] = relationship(
        back_populates="tenant",
        cascade="all, delete-orphan",
    )
    invoices: Mapped[list["Invoice"]] = relationship(
        back_populates="tenant",
        cascade="all, delete-orphan",
    )
    partner_referral: Mapped["PartnerReferral | None"] = relationship(
        back_populates="tenant",
        uselist=False,
    )
    partner_commissions: Mapped[list["PartnerCommission"]] = relationship(
        back_populates="tenant",
        cascade="all, delete-orphan",
    )


class Scan(Base):
    __tablename__ = "scans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    scan_id: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.tenant_id"), index=True)
    scan_type: Mapped[str] = mapped_column(String(20))
    generated_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    data_score: Mapped[int] = mapped_column(Integer)
    checks_count: Mapped[int] = mapped_column(Integer)
    issues_count: Mapped[int] = mapped_column(Integer)
    premium_available: Mapped[bool] = mapped_column(Boolean, default=False)
    summary_headline: Mapped[str] = mapped_column(String(255))
    summary_rating: Mapped[str] = mapped_column(String(30))
    total_records: Mapped[int] = mapped_column(Integer, default=0)
    estimated_loss_eur: Mapped[float] = mapped_column(Float, default=0.0)
    potential_saving_eur: Mapped[float] = mapped_column(Float, default=0.0)
    estimated_premium_price_monthly: Mapped[float] = mapped_column(Float, default=0.0)
    roi_eur: Mapped[float] = mapped_column(Float, default=0.0)
    system_score: Mapped[int] = mapped_column(Integer, default=0)
    finance_score: Mapped[int] = mapped_column(Integer, default=0)
    sales_score: Mapped[int] = mapped_column(Integer, default=0)
    purchasing_score: Mapped[int] = mapped_column(Integer, default=0)
    inventory_score: Mapped[int] = mapped_column(Integer, default=0)
    crm_score: Mapped[int] = mapped_column(Integer, default=0)
    manufacturing_score: Mapped[int] = mapped_column(Integer, default=0)
    service_score: Mapped[int] = mapped_column(Integer, default=0)
    jobs_score: Mapped[int] = mapped_column(Integer, default=0)
    hr_score: Mapped[int] = mapped_column(Integer, default=0)
    customers_count: Mapped[int] = mapped_column(Integer, default=0)
    vendors_count: Mapped[int] = mapped_column(Integer, default=0)
    items_count: Mapped[int] = mapped_column(Integer, default=0)
    customer_ledger_entries_count: Mapped[int] = mapped_column(Integer, default=0)
    vendor_ledger_entries_count: Mapped[int] = mapped_column(Integer, default=0)
    item_ledger_entries_count: Mapped[int] = mapped_column(Integer, default=0)
    sales_headers_count: Mapped[int] = mapped_column(Integer, default=0)
    sales_lines_count: Mapped[int] = mapped_column(Integer, default=0)
    purchase_headers_count: Mapped[int] = mapped_column(Integer, default=0)
    purchase_lines_count: Mapped[int] = mapped_column(Integer, default=0)
    gl_entries_count: Mapped[int] = mapped_column(Integer, default=0)
    value_entries_count: Mapped[int] = mapped_column(Integer, default=0)
    warehouse_entries_count: Mapped[int] = mapped_column(Integer, default=0)

    tenant: Mapped["Tenant"] = relationship(back_populates="scans")
    issues: Mapped[list["ScanIssueRecord"]] = relationship(
        back_populates="scan",
        cascade="all, delete-orphan",
    )


class ScanIssueRecord(Base):
    __tablename__ = "scan_issues"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    scan_id: Mapped[str] = mapped_column(ForeignKey("scans.scan_id"), index=True)
    code: Mapped[str] = mapped_column(String(80), index=True)
    category: Mapped[str] = mapped_column(String(50), default="System", index=True)
    title: Mapped[str] = mapped_column(String(255))
    severity: Mapped[str] = mapped_column(String(20))
    affected_count: Mapped[int] = mapped_column(Integer)
    premium_only: Mapped[bool] = mapped_column(Boolean, default=False)
    recommendation_preview: Mapped[str | None] = mapped_column(Text, nullable=True)
    estimated_impact_eur: Mapped[float] = mapped_column(Float, default=0.0)

    scan: Mapped["Scan"] = relationship(back_populates="issues")


class IssueCostConfig(Base):
    __tablename__ = "issue_cost_config"

    code: Mapped[str] = mapped_column(String(80), primary_key=True)
    title: Mapped[str] = mapped_column(String(255), default="")
    cost_per_record: Mapped[float] = mapped_column(Float, default=10.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class IssueImpactConfig(Base):
    __tablename__ = "issue_impact_config"

    code: Mapped[str] = mapped_column(String(80), primary_key=True)
    title: Mapped[str] = mapped_column(String(255), default="")
    category: Mapped[str] = mapped_column(String(50), default="general")
    minutes_per_occurrence: Mapped[float] = mapped_column(Float, default=5.0)
    probability: Mapped[float] = mapped_column(Float, default=0.2)
    frequency_per_year: Mapped[float] = mapped_column(Float, default=12.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ImpactSettingsConfig(Base):
    __tablename__ = "impact_settings_config"

    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    value_number: Mapped[float] = mapped_column(Float, default=0.0)
    title: Mapped[str] = mapped_column(String(255), default="")


class LicensePricingConfig(Base):
    __tablename__ = "license_pricing_config"

    plan_code: Mapped[str] = mapped_column(String(20), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(80), default="")
    base_price_monthly: Mapped[float] = mapped_column(Float, default=0.0)
    included_records: Mapped[int] = mapped_column(Integer, default=0)
    additional_price_per_1000_records: Mapped[float] = mapped_column(Float, default=0.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.tenant_id"), index=True)
    provider: Mapped[str] = mapped_column(String(30), index=True, default="manual")
    provider_subscription_id: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    status: Mapped[str] = mapped_column(String(30), index=True, default="incomplete")
    plan_code: Mapped[str] = mapped_column(String(20), default="premium")
    currency: Mapped[str] = mapped_column(String(10), default="EUR")
    amount_monthly: Mapped[float] = mapped_column(Float, default=0.0)
    current_period_start_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    current_period_end_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, default=False)
    canceled_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    tenant: Mapped["Tenant"] = relationship(back_populates="subscriptions")


class Invoice(Base):
    __tablename__ = "invoices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.tenant_id"), index=True)
    provider: Mapped[str] = mapped_column(String(30), index=True, default="manual")
    provider_invoice_id: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    provider_subscription_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(30), index=True, default="open")
    currency: Mapped[str] = mapped_column(String(10), default="EUR")
    amount_total: Mapped[float] = mapped_column(Float, default=0.0)
    amount_paid: Mapped[float] = mapped_column(Float, default=0.0)
    hosted_invoice_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    paid_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    tenant: Mapped["Tenant"] = relationship(back_populates="invoices")


class BillingWebhookEvent(Base):
    __tablename__ = "billing_webhook_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    provider: Mapped[str] = mapped_column(String(30), index=True)
    event_id: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    event_type: Mapped[str] = mapped_column(String(120), index=True)
    payload_json: Mapped[str] = mapped_column(Text)
    received_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    processed_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Partner(Base):
    __tablename__ = "partners"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    partner_code: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    contact_email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    default_commission_rate: Mapped[float] = mapped_column(Float, default=0.3)
    last_login_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    referrals: Mapped[list["PartnerReferral"]] = relationship(
        back_populates="partner",
        cascade="all, delete-orphan",
    )
    commissions: Mapped[list["PartnerCommission"]] = relationship(
        back_populates="partner",
        cascade="all, delete-orphan",
    )


class PartnerApplication(Base):
    __tablename__ = "partner_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    company_name: Mapped[str] = mapped_column(String(160))
    contact_name: Mapped[str] = mapped_column(String(120))
    contact_email: Mapped[str] = mapped_column(String(255), index=True)
    phone: Mapped[str | None] = mapped_column(String(60), nullable=True)
    website: Mapped[str | None] = mapped_column(String(255), nullable=True)
    country: Mapped[str | None] = mapped_column(String(80), nullable=True)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_page: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="new", index=True)
    mail_status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    last_mail_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_mail_sent_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    reviewed_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)


class PartnerReferral(Base):
    __tablename__ = "partner_referrals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    partner_id: Mapped[int] = mapped_column(ForeignKey("partners.id"), index=True)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.tenant_id"), unique=True, index=True)
    referral_code: Mapped[str] = mapped_column(String(80), index=True)
    attribution_source: Mapped[str] = mapped_column(String(80), default="manual")
    attributed_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    partner: Mapped["Partner"] = relationship(back_populates="referrals")
    tenant: Mapped["Tenant"] = relationship(back_populates="partner_referral")


class PartnerCommission(Base):
    __tablename__ = "partner_commissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    partner_id: Mapped[int] = mapped_column(ForeignKey("partners.id"), index=True)
    tenant_id: Mapped[str] = mapped_column(ForeignKey("tenants.tenant_id"), index=True)
    invoice_id: Mapped[int | None] = mapped_column(ForeignKey("invoices.id"), nullable=True, index=True)
    provider_invoice_id: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    currency: Mapped[str] = mapped_column(String(10), default="EUR")
    base_amount: Mapped[float] = mapped_column(Float, default=0.0)
    commission_rate: Mapped[float] = mapped_column(Float, default=0.3)
    commission_amount: Mapped[float] = mapped_column(Float, default=0.0)
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    approved_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    paid_at_utc: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    partner: Mapped["Partner"] = relationship(back_populates="commissions")
    tenant: Mapped["Tenant"] = relationship(back_populates="partner_commissions")


class AdminAuditEvent(Base):
    __tablename__ = "admin_audit_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    admin_username: Mapped[str] = mapped_column(String(120), index=True)
    action: Mapped[str] = mapped_column(String(80), index=True)
    target_type: Mapped[str] = mapped_column(String(60), index=True)
    target_id: Mapped[str] = mapped_column(String(120), index=True)
    details_json: Mapped[str] = mapped_column(Text, default="{}")
    created_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class AdminEmailTemplate(Base):
    __tablename__ = "admin_email_templates"

    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    subject_template: Mapped[str] = mapped_column(String(255))
    html_template: Mapped[str] = mapped_column(Text)
    updated_at_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
