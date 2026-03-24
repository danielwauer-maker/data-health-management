from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant
from app.schemas.scan import DataProfile

router = APIRouter(tags=["scans"])


class ScanIssuePayload(BaseModel):
    code: str
    title: str
    severity: str
    affected_count: int
    premium_only: bool = False
    recommendation_preview: Optional[str] = None
    estimated_impact_eur: float = Field(default=0.0, ge=0)


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
    data_profile: DataProfile = Field(default_factory=DataProfile)
    estimated_loss_eur: float = Field(default=0.0, ge=0)
    potential_saving_eur: float = Field(default=0.0, ge=0)
    estimated_premium_price_monthly: float = Field(default=0.0, ge=0)
    roi_eur: float = 0.0


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

        scan.total_records = payload.data_profile.total_records
        scan.customer_count = payload.data_profile.customers
        scan.vendor_count = payload.data_profile.vendors
        scan.item_count = payload.data_profile.items
        scan.customer_ledger_entry_count = payload.data_profile.customer_ledger_entries
        scan.vendor_ledger_entry_count = payload.data_profile.vendor_ledger_entries
        scan.item_ledger_entry_count = payload.data_profile.item_ledger_entries
        scan.sales_header_count = payload.data_profile.sales_headers
        scan.sales_line_count = payload.data_profile.sales_lines
        scan.purchase_header_count = payload.data_profile.purchase_headers
        scan.purchase_line_count = payload.data_profile.purchase_lines
        scan.gl_entry_count = payload.data_profile.gl_entries
        scan.value_entry_count = payload.data_profile.value_entries
        scan.warehouse_entry_count = payload.data_profile.warehouse_entries
        scan.estimated_loss_eur = payload.estimated_loss_eur
        scan.potential_saving_eur = payload.potential_saving_eur
        scan.estimated_premium_price_monthly = payload.estimated_premium_price_monthly
        scan.roi_eur = payload.roi_eur

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
                    estimated_impact_eur=issue.estimated_impact_eur,
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
