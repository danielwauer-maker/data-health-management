from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord, Tenant
from app.services.cost_service import calculate_issue_impact, get_issue_cost_map
from app.services.pricing_service import calculate_monthly_price, get_license_pricing

router = APIRouter(tags=["scans"])


class DataProfilePayload(BaseModel):
    customers: int = 0
    vendors: int = 0
    items: int = 0
    customer_ledger_entries: int = 0
    vendor_ledger_entries: int = 0
    item_ledger_entries: int = 0
    sales_headers: int = 0
    sales_lines: int = 0
    purchase_headers: int = 0
    purchase_lines: int = 0
    gl_entries: int = 0
    value_entries: int = 0
    warehouse_entries: int = 0
    total_records: int = 0


class ScanIssuePayload(BaseModel):
    code: str
    title: str
    severity: str
    affected_count: int
    premium_only: bool = False
    recommendation_preview: Optional[str] = None
    estimated_impact_eur: float = 0.0


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
    data_profile: DataProfilePayload = DataProfilePayload()
    estimated_loss_eur: float = 0.0
    potential_saving_eur: float = 0.0
    estimated_premium_price_monthly: float = 0.0
    roi_eur: float = 0.0
    issues: List[ScanIssuePayload] = []


@router.post("/scan/sync")
def sync_scan(payload: ScanSyncPayload):
    with SessionLocal() as db:
        tenant = db.query(Tenant).filter(Tenant.tenant_id == payload.tenant_id).first()
        if tenant is None:
            raise HTTPException(status_code=404, detail="Tenant not found.")

        cost_map = get_issue_cost_map(db)
        pricing = get_license_pricing(db, "premium")
        total_records = int(payload.data_profile.total_records or 0)
        estimated_loss = float(payload.estimated_loss_eur or 0.0)
        if estimated_loss <= 0:
            estimated_loss = round(
                sum(calculate_issue_impact(issue.code, issue.affected_count, cost_map) for issue in payload.issues),
                2,
            )
        potential_saving = float(payload.potential_saving_eur or round(estimated_loss * 0.7, 2))
        premium_price = float(payload.estimated_premium_price_monthly or calculate_monthly_price(total_records, pricing))
        roi = float(payload.roi_eur or round(potential_saving - (premium_price * 12), 2))

        scan = db.query(Scan).filter(Scan.scan_id == payload.scan_id).first()
        if scan is None:
            scan = Scan(scan_id=payload.scan_id, tenant_id=payload.tenant_id, scan_type=payload.scan_type.lower(), generated_at_utc=payload.generated_at_utc, data_score=payload.data_score, checks_count=payload.checks_count, issues_count=payload.issues_count, premium_available=payload.premium_available, summary_headline=payload.headline, summary_rating=payload.rating)
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

        scan.total_records = total_records
        scan.estimated_loss_eur = estimated_loss
        scan.potential_saving_eur = potential_saving
        scan.estimated_premium_price_monthly = premium_price
        scan.roi_eur = roi
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
                    estimated_impact_eur=float(issue.estimated_impact_eur or calculate_issue_impact(issue.code, issue.affected_count, cost_map)),
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
