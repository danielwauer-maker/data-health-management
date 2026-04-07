from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import select

from app.core.settings import validate_settings
from app.db import SessionLocal, ensure_schema_is_migrated, wait_for_database
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
from app.security.tenant import (
    enforce_tenant_match,
    load_authenticated_tenant,
    require_tenant_headers,
)
from app.services.cost_service import ensure_default_issue_costs
from app.services.impact_service import (
    apply_commercials_to_scan,
    calculate_scan_commercials,
    ensure_default_impact_config,
    normalize_stored_commercials,
)
from app.services.pricing_service import ensure_default_license_pricing
from app.services.scoring_service import calculate_quick_scan_result
import os
from fastapi.responses import RedirectResponse

BASE_DIR = Path(__file__).resolve().parent


@asynccontextmanager
async def lifespan(app: FastAPI):
    validate_settings()
    wait_for_database()
    ensure_schema_is_migrated()

    with SessionLocal() as db:
        ensure_default_issue_costs(db)
        ensure_default_impact_config(db)
        ensure_default_license_pricing(db)

    yield


app = FastAPI(
    title="Data Health Management API",
    version="0.7.0",
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

ENVIRONMENT = os.getenv("APP_ENV", "prod")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}

@app.get("/", include_in_schema=False)
def root():
    return {
        "status": "ok",
        "service": "BCSentinel API",
        "environment": ENVIRONMENT,
        "endpoints": {
            "health": "/health",
            "docs": "/docs"
        }
    }


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
def quick_scan(
    payload: QuickScanRequest,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> QuickScanResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)

        data_score, checks_count, issues_count, summary, issues = calculate_quick_scan_result(
            payload.metrics
        )
        scan_id = (payload.bc_run_id or "").strip() or f"scan_{uuid4().hex[:12]}"
        generated_at_utc = datetime.now(timezone.utc)
        total_records = int(payload.data_profile.total_records or 0)

        commercials = calculate_scan_commercials(
            db,
            issues=issues,
            total_records=total_records,
        )

        enriched_issue_dicts = commercials["issues"]
        enriched_issues = [ScanIssue(**issue_dict) for issue_dict in enriched_issue_dicts]

        existing_scan = db.scalar(select(Scan).where(Scan.scan_id == scan_id))

        if existing_scan is not None and existing_scan.tenant_id != payload.tenant_id:
            raise HTTPException(
                status_code=409,
                detail="scan_id already exists for another tenant.",
            )

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
            apply_commercials_to_scan(scan, commercials)
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
            apply_commercials_to_scan(scan, commercials)
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

        normalized_commercials = normalize_stored_commercials(
            total_records=scan.total_records,
            estimated_loss_eur=scan.estimated_loss_eur,
            potential_saving_eur=scan.potential_saving_eur,
            estimated_premium_price_monthly=scan.estimated_premium_price_monthly,
        )

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
        estimated_loss_eur=float(normalized_commercials["estimated_loss_eur"]),
        potential_saving_eur=float(normalized_commercials["potential_saving_eur"]),
        estimated_premium_price_monthly=float(normalized_commercials["estimated_premium_price_monthly"]),
        roi_eur=float(normalized_commercials["roi_eur"]),
    )


@app.get("/scan/history/{tenant_id}", response_model=ScanHistoryResponse)
def get_scan_history(
    tenant_id: str,
    limit: int = 10,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> ScanHistoryResponse:
    header_tenant_id, header_api_token = tenant_auth
    safe_limit = min(max(limit, 1), 50)

    enforce_tenant_match(tenant_id, header_tenant_id, "Path tenant_id")

    with SessionLocal() as db:
        load_authenticated_tenant(db, header_tenant_id, header_api_token)

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

            normalized_commercials = normalize_stored_commercials(
                total_records=scan.total_records,
                estimated_loss_eur=scan.estimated_loss_eur,
                potential_saving_eur=scan.potential_saving_eur,
                estimated_premium_price_monthly=scan.estimated_premium_price_monthly,
            )

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
                    estimated_loss_eur=float(normalized_commercials["estimated_loss_eur"]),
                    potential_saving_eur=float(normalized_commercials["potential_saving_eur"]),
                    estimated_premium_price_monthly=float(
                        normalized_commercials["estimated_premium_price_monthly"]
                    ),
                    roi_eur=float(normalized_commercials["roi_eur"]),
                )
            )

    return ScanHistoryResponse(
        tenant_id=tenant_id,
        scans=result_scans,
    )


@app.get("/scan/trend/{tenant_id}", response_model=ScanTrendResponse)
def get_scan_trend(
    tenant_id: str,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
) -> ScanTrendResponse:
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(tenant_id, header_tenant_id, "Path tenant_id")

    with SessionLocal() as db:
        load_authenticated_tenant(db, header_tenant_id, header_api_token)

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
