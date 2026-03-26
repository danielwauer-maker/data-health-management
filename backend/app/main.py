from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import select, text

from app.db import Base, SessionLocal, engine, wait_for_database
from app.models import Scan, ScanIssueRecord, Tenant
from app.routers.admin import router as admin_router
from app.routers.analytics import router as analytics_router
from app.routers.license import router as license_router
from app.routers.scans import router as scans_router
from app.schemas.scan import (
    QuickScanRequest,
    QuickScanResponse,
    ScanHistoryEntry,
    ScanHistoryResponse,
    ScanIssue,
    ScanSummary,
    ScanTrendResponse,
)
from app.services.cost_service import ensure_default_issue_costs
from app.services.impact_service import ensure_default_impact_config
from app.services.pricing_service import calculate_monthly_price, ensure_default_license_pricing, get_license_pricing
from app.services.scoring_service import calculate_quick_scan_result

BASE_DIR = Path(__file__).resolve().parent


def ensure_runtime_schema() -> None:
    statements = [
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS total_records INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS estimated_loss_eur DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS potential_saving_eur DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS estimated_premium_price_monthly DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS roi_eur DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS customers_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS vendors_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS items_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS customer_ledger_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS vendor_ledger_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS item_ledger_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS sales_headers_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS sales_lines_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS purchase_headers_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS purchase_lines_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS gl_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS value_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scans ADD COLUMN IF NOT EXISTS warehouse_entries_count INTEGER DEFAULT 0",
        "ALTER TABLE scan_issues ADD COLUMN IF NOT EXISTS estimated_impact_eur DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE issue_cost_config ADD COLUMN IF NOT EXISTS title VARCHAR(255) DEFAULT ''",
        "ALTER TABLE license_pricing_config ADD COLUMN IF NOT EXISTS display_name VARCHAR(80) DEFAULT ''",
        "ALTER TABLE license_pricing_config ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE",
        "CREATE TABLE IF NOT EXISTS issue_impact_config (code VARCHAR(80) PRIMARY KEY)",
        "ALTER TABLE issue_impact_config ADD COLUMN IF NOT EXISTS title VARCHAR(255) DEFAULT ''",
        "ALTER TABLE issue_impact_config ADD COLUMN IF NOT EXISTS minutes_per_occurrence DOUBLE PRECISION DEFAULT 5",
        "ALTER TABLE issue_impact_config ADD COLUMN IF NOT EXISTS probability DOUBLE PRECISION DEFAULT 0.2",
        "ALTER TABLE issue_impact_config ADD COLUMN IF NOT EXISTS frequency_per_year DOUBLE PRECISION DEFAULT 12",
        "ALTER TABLE issue_impact_config ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE",
        "CREATE TABLE IF NOT EXISTS impact_settings_config (key VARCHAR(80) PRIMARY KEY)",
        "ALTER TABLE impact_settings_config ADD COLUMN IF NOT EXISTS value_number DOUBLE PRECISION DEFAULT 0",
        "ALTER TABLE impact_settings_config ADD COLUMN IF NOT EXISTS title VARCHAR(255) DEFAULT ''",
        "DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'impact_settings_config' AND column_name = 'value') THEN UPDATE impact_settings_config SET value_number = COALESCE(value_number, value) WHERE value_number IS NULL OR value_number = 0; END IF; END $$;",
    ]
    with engine.begin() as connection:
        for statement in statements:
            try:
                connection.execute(text(statement))
            except Exception:
                pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    wait_for_database()
    Base.metadata.create_all(bind=engine)
    ensure_runtime_schema()
    with SessionLocal() as db:
        ensure_default_issue_costs(db)
        ensure_default_impact_config(db)
        ensure_default_license_pricing(db)
    yield


app = FastAPI(
    title="Data Health Management API",
    version="0.6.0",
    lifespan=lifespan,
)
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")

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
    from app.services.impact_service import calculate_issue_impacts, get_potential_saving_factor

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == payload.tenant_id))
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        data_score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(payload.metrics)
        scan_id = (payload.bc_run_id or "").strip() or f"scan_{uuid4().hex[:12]}"
        generated_at_utc = datetime.now(timezone.utc)
        total_records = int(payload.data_profile.total_records or 0)

        enriched_issue_dicts = calculate_issue_impacts(db, issues)
        estimated_loss_eur = round(sum(float(issue["estimated_impact_eur"]) for issue in enriched_issue_dicts), 2)
        enriched_issues = [ScanIssue(**issue_dict) for issue_dict in enriched_issue_dicts]

        pricing = get_license_pricing(db, "premium")
        estimated_premium_price_monthly = calculate_monthly_price(total_records, pricing)
        potential_saving_eur = round(estimated_loss_eur * get_potential_saving_factor(db), 2)
        roi_eur = round(potential_saving_eur - (estimated_premium_price_monthly * 12), 2)

        existing_scan = db.scalar(select(Scan).where(Scan.scan_id == scan_id))

        if existing_scan is not None and existing_scan.tenant_id != payload.tenant_id:
            raise HTTPException(status_code=409, detail="scan_id already exists for another tenant.")

        if existing_scan is None:
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
                total_records=total_records,
                estimated_loss_eur=estimated_loss_eur,
                potential_saving_eur=potential_saving_eur,
                estimated_premium_price_monthly=estimated_premium_price_monthly,
                roi_eur=roi_eur,
                customers_count=payload.data_profile.customers,
                vendors_count=payload.data_profile.vendors,
                items_count=payload.data_profile.items,
                customer_ledger_entries_count=payload.data_profile.customer_ledger_entries,
                vendor_ledger_entries_count=payload.data_profile.vendor_ledger_entries,
                item_ledger_entries_count=payload.data_profile.item_ledger_entries,
                sales_headers_count=payload.data_profile.sales_headers,
                sales_lines_count=payload.data_profile.sales_lines,
                purchase_headers_count=payload.data_profile.purchase_headers,
                purchase_lines_count=payload.data_profile.purchase_lines,
                gl_entries_count=payload.data_profile.gl_entries,
                value_entries_count=payload.data_profile.value_entries,
                warehouse_entries_count=payload.data_profile.warehouse_entries,
            )
            db.add(scan)
        else:
            scan = existing_scan
            scan.scan_type = "quick"
            scan.generated_at_utc = generated_at_utc
            scan.data_score = data_score
            scan.checks_count = checks_count
            scan.issues_count = issues_count
            scan.premium_available = True
            scan.summary_headline = summary.headline
            scan.summary_rating = summary.rating
            scan.total_records = total_records
            scan.estimated_loss_eur = estimated_loss_eur
            scan.potential_saving_eur = potential_saving_eur
            scan.estimated_premium_price_monthly = estimated_premium_price_monthly
            scan.roi_eur = roi_eur
            scan.customers_count = payload.data_profile.customers
            scan.vendors_count = payload.data_profile.vendors
            scan.items_count = payload.data_profile.items
            scan.customer_ledger_entries_count = payload.data_profile.customer_ledger_entries
            scan.vendor_ledger_entries_count = payload.data_profile.vendor_ledger_entries
            scan.item_ledger_entries_count = payload.data_profile.item_ledger_entries
            scan.sales_headers_count = payload.data_profile.sales_headers
            scan.sales_lines_count = payload.data_profile.sales_lines
            scan.purchase_headers_count = payload.data_profile.purchase_headers
            scan.purchase_lines_count = payload.data_profile.purchase_lines
            scan.gl_entries_count = payload.data_profile.gl_entries
            scan.value_entries_count = payload.data_profile.value_entries
            scan.warehouse_entries_count = payload.data_profile.warehouse_entries

            db.query(ScanIssueRecord).filter(ScanIssueRecord.scan_id == scan_id).delete()

        for issue in enriched_issues:
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
        bc_run_id=payload.bc_run_id,
        scan_type="quick",
        generated_at_utc=generated_at_utc,
        data_score=data_score,
        checks_count=checks_count,
        issues_count=issues_count,
        premium_available=True,
        summary=summary,
        issues=enriched_issues,
        data_profile=payload.data_profile,
        estimated_loss_eur=round(estimated_loss_eur, 2),
        potential_saving_eur=potential_saving_eur,
        estimated_premium_price_monthly=estimated_premium_price_monthly,
        roi_eur=roi_eur,
    )


@app.get("/scan/history/{tenant_id}", response_model=ScanHistoryResponse)
def get_scan_history(tenant_id: str, limit: int = 10) -> ScanHistoryResponse:
    safe_limit = min(max(limit, 1), 50)

    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
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
                    estimated_impact_eur=float(row.estimated_impact_eur or 0.0),
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
                    data_profile={
                        "customers": scan.customers_count,
                        "vendors": scan.vendors_count,
                        "items": scan.items_count,
                        "customer_ledger_entries": scan.customer_ledger_entries_count,
                        "vendor_ledger_entries": scan.vendor_ledger_entries_count,
                        "item_ledger_entries": scan.item_ledger_entries_count,
                        "sales_headers": scan.sales_headers_count,
                        "sales_lines": scan.sales_lines_count,
                        "purchase_headers": scan.purchase_headers_count,
                        "purchase_lines": scan.purchase_lines_count,
                        "gl_entries": scan.gl_entries_count,
                        "value_entries": scan.value_entries_count,
                        "warehouse_entries": scan.warehouse_entries_count,
                        "total_records": scan.total_records,
                    },
                    estimated_loss_eur=float(scan.estimated_loss_eur or 0.0),
                    potential_saving_eur=float(scan.potential_saving_eur or 0.0),
                    estimated_premium_price_monthly=float(scan.estimated_premium_price_monthly or 0.0),
                    roi_eur=float(scan.roi_eur or 0.0),
                )
            )

    return ScanHistoryResponse(
        tenant_id=tenant_id,
        scans=result_scans,
    )


@app.get("/scan/trend/{tenant_id}", response_model=ScanTrendResponse)
def get_scan_trend(tenant_id: str) -> ScanTrendResponse:
    with SessionLocal() as db:
        tenant = db.scalar(select(Tenant).where(Tenant.tenant_id == tenant_id))
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

    latest = scans[0]
    previous = scans[1] if len(scans) > 1 else None

    latest_score = latest.data_score
    previous_score = previous.data_score if previous else None
    delta = (latest_score - previous_score) if previous_score is not None else None

    if delta is None or delta == 0:
        trend = "same"
    elif delta > 0:
        trend = "up"
    else:
        trend = "down"

    return ScanTrendResponse(
        tenant_id=tenant_id,
        latest_scan_id=latest.scan_id,
        previous_scan_id=previous.scan_id if previous else None,
        latest_score=latest_score,
        previous_score=previous_score,
        delta=delta,
        trend=trend,
    )
