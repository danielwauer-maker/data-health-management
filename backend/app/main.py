from contextlib import asynccontextmanager
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import select

from app.db import Base, SessionLocal, engine, wait_for_database
from app.models import Scan, ScanIssueRecord, Tenant
from app.routers.admin import router as admin_router
from app.routers.analytics import router as analytics_router
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
from app.services.scoring_service import calculate_quick_scan_result
from app.routers.license import router as license_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    wait_for_database()
    Base.metadata.create_all(bind=engine)
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
