from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant

router = APIRouter(tags=["scans"])


class ScanIssuePayload(BaseModel):
    code: str
    title: str
    severity: str
    affected_count: int
    premium_only: bool = False
    recommendation_preview: Optional[str] = None


class ScanSyncPayload(BaseModel):
    tenant_id: str
    scan_id: str
    scan_type: str
    generated_at_utc: datetime
    data_score: int
    checks_count: int
    issues_count: int
    premium_available: bool = True
    headline: str = ""
    rating: str = ""
    issues: List[ScanIssuePayload] = []


@router.post("/scan/sync")
def sync_scan(payload: ScanSyncPayload):
    with SessionLocal() as db:
        tenant = db.query(Tenant).filter(Tenant.tenant_id == payload.tenant_id).first()
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        scan = db.query(Scan).filter(Scan.scan_id == payload.scan_id).first()

        if scan is None:
            scan = Scan(
                scan_id=payload.scan_id,
                tenant_id=payload.tenant_id,
                scan_type=payload.scan_type.lower(),
                generated_at_utc=payload.generated_at_utc,
                data_score=payload.data_score,
                checks_count=payload.checks_count,
                issues_count=payload.issues_count,
                premium_available=payload.premium_available,
                summary_headline=payload.headline,
                summary_rating=payload.rating,
            )
            db.add(scan)
            db.flush()
        else:
            scan.tenant_id = payload.tenant_id
            scan.scan_type = payload.scan_type.lower()
            scan.generated_at_utc = payload.generated_at_utc
            scan.data_score = payload.data_score
            scan.checks_count = payload.checks_count
            scan.issues_count = payload.issues_count
            scan.premium_available = payload.premium_available
            scan.summary_headline = payload.headline
            scan.summary_rating = payload.rating

            db.query(ScanIssueRecord).filter(ScanIssueRecord.scan_id == payload.scan_id).delete()

        tenant.last_seen_at_utc = datetime.now(timezone.utc)

        for issue in payload.issues:
            db.add(
                ScanIssueRecord(
                    scan_id=payload.scan_id,
                    code=issue.code,
                    title=issue.title,
                    severity=issue.severity,
                    affected_count=issue.affected_count,
                    premium_only=issue.premium_only,
                    recommendation_preview=issue.recommendation_preview,
                )
            )

        db.commit()

    return JSONResponse(content={"status": "ok"})


@router.delete("/scan/{scan_id}")
def delete_scan(scan_id: str):
    with SessionLocal() as db:
        scan = db.query(Scan).filter(Scan.scan_id == scan_id).first()
        if scan is None:
            return JSONResponse(content={"status": "not_found"})

        db.delete(scan)
        db.commit()

    return JSONResponse(content={"status": "deleted"})
