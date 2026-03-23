from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
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

    scan: Mapped["Scan"] = relationship(back_populates="issues")
