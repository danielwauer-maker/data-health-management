from contextlib import asynccontextmanager
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, text

from app.db import Base, SessionLocal, engine, wait_for_database
from app.models import Scan, ScanIssueRecord, Tenant
from app.routers.admin import router as admin_router
from app.routers.analytics import router as analytics_router
from app.routers.scans import router as scans_router
from app.schemas.scan import (
    DataProfile,
    QuickScanRequest,
    QuickScanResponse,
    ScanHistoryEntry,
    ScanHistoryResponse,
    ScanIssue,
    ScanSummary,
    ScanTrendResponse,
)
from app.services.cost_service import enrich_issues_with_costs
from app.services.pricing_service import (
    calculate_estimated_premium_price_monthly,
    calculate_roi_eur,
)
from app.services.scoring_service import calculate_quick_scan_result
from app.routers.license import router as license_router


def ensure_runtime_schema() -> None:
    statements = [
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS total_records INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS customer_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS vendor_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS item_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS customer_ledger_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS vendor_ledger_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS item_ledger_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS sales_header_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS sales_line_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS purchase_header_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS purchase_line_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS gl_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS value_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS warehouse_entry_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS estimated_loss_eur DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS potential_saving_eur DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS estimated_premium_price_monthly DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS roi_eur DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE scan_issues ADD COLUMN IF NOT EXISTS estimated_impact_eur DOUBLE PRECISION NOT NULL DEFAULT 0",
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


@asynccontextmanager
async def lifespan(app: FastAPI):
    wait_for_database()
    Base.metadata.create_all(bind=engine)
    ensure_runtime_schema()
    yield


app = FastAPI(
    title="Data Health Management API",
    version="0.5.0",
    lifespan=lifespan,
)

app.include_router(admin_router)
app.include_router(analytics_router)
app.include_router(scans_router)
app.include_router(license_router)


class TenantRegisterRequest(BaseModel):
    environment_name: str
    app_version: str


class TenantRegisterResponse(BaseModel):
    tenant_id: str
    api_token: str


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/tenant/register", response_model=TenantRegisterResponse)
def register_tenant(payload: TenantRegisterRequest) -> TenantRegisterResponse:
    tenant_id = f"ten_{uuid4().hex[:12]}"
    api_token = f"tok_{uuid4().hex}"
    now_utc = datetime.now(timezone.utc)

    with SessionLocal() as db:
        tenant = Tenant(
            tenant_id=tenant_id,
            api_token=api_token,
            environment_name=payload.environment_name,
            app_version=payload.app_version,
            created_at_utc=now_utc,
            last_seen_at_utc=now_utc,
            current_plan="free",
            license_status="trial",
        )
        db.add(tenant)
        db.commit()

    return TenantRegisterResponse(
        tenant_id=tenant_id,
        api_token=api_token,
    )


@app.post("/scan/quick", response_model=QuickScanResponse)
def quick_scan(payload: QuickScanRequest) -> QuickScanResponse:
    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == payload.tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        data_score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(
            payload.metrics
        )
        issues, estimated_loss_eur = enrich_issues_with_costs(issues)
        estimated_premium_price_monthly = calculate_estimated_premium_price_monthly(payload.data_profile)
        potential_saving_eur = estimated_loss_eur
        roi_eur = calculate_roi_eur(estimated_loss_eur, estimated_premium_price_monthly)

        scan_id = f"scan_{uuid4().hex[:12]}"
        generated_at_utc = datetime.now(timezone.utc)

        scan = Scan(
            scan_id=scan_id,
            tenant_id=payload.tenant_id,
            scan_type="quick",
            generated_at_utc=generated_at_utc,
            data_score=data_score,
            checks_count=checks_count,
            issues_count=issues_count,
            premium_available=True,
            summary_headline=summary.headline,
            summary_rating=summary.rating,
            total_records=payload.data_profile.total_records,
            customer_count=payload.data_profile.customers,
            vendor_count=payload.data_profile.vendors,
            item_count=payload.data_profile.items,
            customer_ledger_entry_count=payload.data_profile.customer_ledger_entries,
            vendor_ledger_entry_count=payload.data_profile.vendor_ledger_entries,
            item_ledger_entry_count=payload.data_profile.item_ledger_entries,
            sales_header_count=payload.data_profile.sales_headers,
            sales_line_count=payload.data_profile.sales_lines,
            purchase_header_count=payload.data_profile.purchase_headers,
            purchase_line_count=payload.data_profile.purchase_lines,
            gl_entry_count=payload.data_profile.gl_entries,
            value_entry_count=payload.data_profile.value_entries,
            warehouse_entry_count=payload.data_profile.warehouse_entries,
            estimated_loss_eur=estimated_loss_eur,
            potential_saving_eur=potential_saving_eur,
            estimated_premium_price_monthly=estimated_premium_price_monthly,
            roi_eur=roi_eur,
        )
        db.add(scan)

        for issue in issues:
            db.add(
                ScanIssueRecord(
                    scan_id=scan_id,
                    code=issue.code,
                    title=issue.title,
                    severity=issue.severity,
                    affected_count=issue.affected_count,
                    premium_only=issue.premium_only,
                    recommendation_preview=issue.recommendation_preview,
                    estimated_impact_eur=issue.estimated_impact_eur,
                )
            )

        tenant.last_seen_at_utc = generated_at_utc
        db.commit()

    return QuickScanResponse(
        scan_id=scan_id,
        scan_type="quick",
        generated_at_utc=generated_at_utc,
        data_score=data_score,
        checks_count=checks_count,
        issues_count=issues_count,
        premium_available=True,
        summary=summary,
        issues=issues,
        data_profile=payload.data_profile,
        estimated_loss_eur=estimated_loss_eur,
        potential_saving_eur=potential_saving_eur,
        estimated_premium_price_monthly=estimated_premium_price_monthly,
        roi_eur=roi_eur,
    )


@app.get("/scan/history/{tenant_id}", response_model=ScanHistoryResponse)
def get_scan_history(tenant_id: str, limit: int = 10) -> ScanHistoryResponse:
    safe_limit = min(max(limit, 1), 50)

    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(safe_limit)
        ).all()

        result_scans: list[ScanHistoryEntry] = []

        for scan in scans:
            issue_rows = db.scalars(
                select(ScanIssueRecord)
                .where(ScanIssueRecord.scan_id == scan.scan_id)
                .order_by(ScanIssueRecord.affected_count.desc())
            ).all()

            issues = [
                ScanIssue(
                    code=row.code,
                    title=row.title,
                    severity=row.severity,
                    affected_count=row.affected_count,
                    premium_only=row.premium_only,
                    recommendation_preview=row.recommendation_preview,
                    estimated_impact_eur=row.estimated_impact_eur,
                )
                for row in issue_rows
            ]

            result_scans.append(
                ScanHistoryEntry(
                    scan_id=scan.scan_id,
                    scan_type=scan.scan_type,
                    generated_at_utc=scan.generated_at_utc,
                    data_score=scan.data_score,
                    checks_count=scan.checks_count,
                    issues_count=scan.issues_count,
                    premium_available=scan.premium_available,
                    summary=ScanSummary(
                        headline=scan.summary_headline,
                        rating=scan.summary_rating,
                    ),
                    issues=issues,
                    data_profile=DataProfile(
                        customers=scan.customer_count,
                        vendors=scan.vendor_count,
                        items=scan.item_count,
                        customer_ledger_entries=scan.customer_ledger_entry_count,
                        vendor_ledger_entries=scan.vendor_ledger_entry_count,
                        item_ledger_entries=scan.item_ledger_entry_count,
                        sales_headers=scan.sales_header_count,
                        sales_lines=scan.sales_line_count,
                        purchase_headers=scan.purchase_header_count,
                        purchase_lines=scan.purchase_line_count,
                        gl_entries=scan.gl_entry_count,
                        value_entries=scan.value_entry_count,
                        warehouse_entries=scan.warehouse_entry_count,
                        total_records=scan.total_records,
                    ),
                    estimated_loss_eur=scan.estimated_loss_eur,
                    potential_saving_eur=scan.potential_saving_eur,
                    estimated_premium_price_monthly=scan.estimated_premium_price_monthly,
                    roi_eur=scan.roi_eur,
                )
            )

    return ScanHistoryResponse(
        tenant_id=tenant_id,
        scans=result_scans,
    )


@app.get("/scan/trend/{tenant_id}", response_model=ScanTrendResponse)
def get_scan_trend(tenant_id: str) -> ScanTrendResponse:
    with SessionLocal() as db:
        tenant = db.scalar(
            select(Tenant).where(Tenant.tenant_id == tenant_id)
        )
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        scans = db.scalars(
            select(Scan)
            .where(Scan.tenant_id == tenant_id)
            .order_by(Scan.generated_at_utc.desc())
            .limit(2)
        ).all()

        if not scans:
            return ScanTrendResponse(
                tenant_id=tenant_id,
                trend="same",
            )

        if len(scans) == 1:
            return ScanTrendResponse(
                tenant_id=tenant_id,
                trend="same",
            )

        latest = scans[0]
        previous = scans[1]

        if latest.data_score > previous.data_score:
            trend = "up"
        elif latest.data_score < previous.data_score:
            trend = "down"
        else:
            trend = "same"

        return ScanTrendResponse(
            tenant_id=tenant_id,
            trend=trend,
        )
