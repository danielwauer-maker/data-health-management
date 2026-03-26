from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    tenant_id: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    api_token: Mapped[str] = mapped_column(String(80), unique=True, index=True)
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
    premium_available: Mapped[bool] = mapped_column(Boolean, default=True)
    summary_headline: Mapped[str] = mapped_column(String(255))
    summary_rating: Mapped[str] = mapped_column(String(30))
    total_records: Mapped[int] = mapped_column(Integer, default=0)
    estimated_loss_eur: Mapped[float] = mapped_column(Float, default=0.0)
    potential_saving_eur: Mapped[float] = mapped_column(Float, default=0.0)
    estimated_premium_price_monthly: Mapped[float] = mapped_column(Float, default=0.0)
    roi_eur: Mapped[float] = mapped_column(Float, default=0.0)
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
