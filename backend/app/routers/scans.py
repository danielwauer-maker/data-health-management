from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.db import SessionLocal
from app.models import Scan, ScanIssueRecord
from app.security.tenant import (
    enforce_tenant_match,
    load_authenticated_tenant,
    require_tenant_headers,
)
from app.services.impact_service import (
    apply_commercials_to_scan,
    calculate_scan_commercials,
    normalize_stored_commercials,
)
from app.services.entitlement_guard_service import get_tenant_features, require_tenant_feature
from app.services.entitlement_service import is_premium_actions_enabled

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
    category: Optional[str] = None
    title: str
    severity: str
    affected_count: int
    premium_only: bool = False
    recommendation_preview: Optional[str] = None
    estimated_impact_eur: float = 0.0


class ModuleScoresPayload(BaseModel):
    system: int = 0
    finance: int = 0
    sales: int = 0
    purchasing: int = 0
    inventory: int = 0
    crm: int = 0
    manufacturing: int = 0
    service: int = 0
    jobs: int = 0
    hr: int = 0


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
    data_profile: DataProfilePayload = Field(default_factory=DataProfilePayload)
    estimated_loss_eur: float = 0.0
    potential_saving_eur: float = 0.0
    estimated_premium_price_monthly: float = 0.0
    roi_eur: float = 0.0
    module_scores: ModuleScoresPayload = Field(default_factory=ModuleScoresPayload)
    issues: List[ScanIssuePayload] = Field(default_factory=list)


class ScanReconcilePayload(BaseModel):
    tenant_id: str
    scan_ids: List[str] = Field(default_factory=list)


def _safe_int(value: object, default: int = 0) -> int:
    try:
        return int(value or default)
    except (TypeError, ValueError):
        return default


def _safe_float(value: object, default: float = 0.0) -> float:
    try:
        return float(value or default)
    except (TypeError, ValueError):
        return default


def _normalize_scan_type(value: str | None) -> str:
    normalized = (value or "").strip().lower()
    if normalized in {"deep", "premium_deep"}:
        return "deep"
    return "quick"


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _calculate_commercials(payload: ScanSyncPayload, db) -> dict[str, object]:
    commercials = calculate_scan_commercials(
        db,
        issues=payload.issues,
        total_records=_safe_int(payload.data_profile.total_records),
        supplied_estimated_loss_eur=_safe_float(payload.estimated_loss_eur),
        supplied_estimated_premium_price_monthly=_safe_float(payload.estimated_premium_price_monthly),
    )

    return {
        "total_records": int(commercials["total_records"]),
        "estimated_loss_eur": float(commercials["estimated_loss_eur"]),
        "potential_saving_eur": float(commercials["potential_saving_eur"]),
        "estimated_premium_price_monthly": float(commercials["estimated_premium_price_monthly"]),
        "roi_eur": float(commercials["roi_eur"]),
        "issues": list(commercials["issues"]),
    }


@router.post("/scan/sync")
def sync_scan(
    payload: ScanSyncPayload,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
):
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        tenant_features = get_tenant_features(db, tenant)
        require_tenant_feature(db, tenant, "scan_sync")
        commercials = _calculate_commercials(payload, db)
        recalculated_issues = list(commercials["issues"])

        existing_scan = db.scalar(select(Scan).where(Scan.scan_id == payload.scan_id))

        if existing_scan is not None and existing_scan.tenant_id != payload.tenant_id:
            raise HTTPException(status_code=409, detail="scan_id already exists for another tenant.")

        scan = existing_scan
        normalized_generated_at = _normalize_utc(payload.generated_at_utc)
        normalized_scan_type = _normalize_scan_type(payload.scan_type)

        if scan is None:
            scan = Scan(
                scan_id=payload.scan_id,
                tenant_id=payload.tenant_id,
                scan_type=normalized_scan_type,
                generated_at_utc=normalized_generated_at,
                data_score=_safe_int(payload.data_score),
                checks_count=_safe_int(payload.checks_count),
                issues_count=_safe_int(payload.issues_count),
                premium_available=is_premium_actions_enabled(tenant_features),
                summary_headline=payload.headline or "",
                summary_rating=payload.rating or "",
            )
            db.add(scan)
            db.flush()
        else:
            scan.tenant_id = payload.tenant_id
            scan.scan_type = normalized_scan_type
            scan.generated_at_utc = normalized_generated_at
            scan.data_score = _safe_int(payload.data_score)
            scan.checks_count = _safe_int(payload.checks_count)
            scan.issues_count = _safe_int(payload.issues_count)
            scan.premium_available = is_premium_actions_enabled(tenant_features)
            scan.summary_headline = payload.headline or ""
            scan.summary_rating = payload.rating or ""

            db.query(ScanIssueRecord).filter(ScanIssueRecord.scan_id == payload.scan_id).delete()

        apply_commercials_to_scan(scan, commercials)

        scan.system_score = _safe_int(payload.module_scores.system)
        scan.finance_score = _safe_int(payload.module_scores.finance)
        scan.sales_score = _safe_int(payload.module_scores.sales)
        scan.purchasing_score = _safe_int(payload.module_scores.purchasing)
        scan.inventory_score = _safe_int(payload.module_scores.inventory)
        scan.crm_score = _safe_int(payload.module_scores.crm)
        scan.manufacturing_score = _safe_int(payload.module_scores.manufacturing)
        scan.service_score = _safe_int(payload.module_scores.service)
        scan.jobs_score = _safe_int(payload.module_scores.jobs)
        scan.hr_score = _safe_int(payload.module_scores.hr)

        scan.customers_count = _safe_int(payload.data_profile.customers)
        scan.vendors_count = _safe_int(payload.data_profile.vendors)
        scan.items_count = _safe_int(payload.data_profile.items)
        scan.customer_ledger_entries_count = _safe_int(payload.data_profile.customer_ledger_entries)
        scan.vendor_ledger_entries_count = _safe_int(payload.data_profile.vendor_ledger_entries)
        scan.item_ledger_entries_count = _safe_int(payload.data_profile.item_ledger_entries)
        scan.sales_headers_count = _safe_int(payload.data_profile.sales_headers)
        scan.sales_lines_count = _safe_int(payload.data_profile.sales_lines)
        scan.purchase_headers_count = _safe_int(payload.data_profile.purchase_headers)
        scan.purchase_lines_count = _safe_int(payload.data_profile.purchase_lines)
        scan.gl_entries_count = _safe_int(payload.data_profile.gl_entries)
        scan.value_entries_count = _safe_int(payload.data_profile.value_entries)
        scan.warehouse_entries_count = _safe_int(payload.data_profile.warehouse_entries)

        tenant.last_seen_at_utc = datetime.now(timezone.utc)

        for issue in recalculated_issues:
            db.add(
                ScanIssueRecord(
                    scan_id=payload.scan_id,
                    code=str(issue["code"]),
                    category=str(issue.get("category") or "System"),
                    title=str(issue["title"]),
                    severity=str(issue["severity"]),
                    affected_count=_safe_int(issue["affected_count"]),
                    premium_only=bool(issue["premium_only"]),
                    recommendation_preview=issue["recommendation_preview"],
                    estimated_impact_eur=_safe_float(issue["estimated_impact_eur"]),
                )
            )

        db.commit()

    return JSONResponse(
        content={
            "status": "ok",
            "scan_id": payload.scan_id,
            "tenant_id": payload.tenant_id,
            "commercials": normalize_stored_commercials(
                total_records=int(commercials["total_records"]),
                estimated_loss_eur=float(commercials["estimated_loss_eur"]),
                potential_saving_eur=float(commercials["potential_saving_eur"]),
                estimated_premium_price_monthly=float(commercials["estimated_premium_price_monthly"]),
            ),
            "issues": recalculated_issues,
        }
    )


@router.post("/scan/reconcile")
def reconcile_scans(
    payload: ScanReconcilePayload,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
):
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(payload.tenant_id, header_tenant_id, "Payload tenant_id")

    keep_ids = {scan_id.strip() for scan_id in payload.scan_ids if scan_id and scan_id.strip()}

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        require_tenant_feature(db, tenant, "scan_sync")

        scans = db.scalars(select(Scan).where(Scan.tenant_id == payload.tenant_id)).all()
        deleted_ids: list[str] = []

        for scan in scans:
            if scan.scan_id not in keep_ids:
                deleted_ids.append(scan.scan_id)
                db.query(ScanIssueRecord).filter(ScanIssueRecord.scan_id == scan.scan_id).delete()
                db.delete(scan)

        db.commit()

    return JSONResponse(
        content={
            "status": "ok",
            "tenant_id": payload.tenant_id,
            "deleted_scan_ids": deleted_ids,
            "kept_scan_ids": sorted(keep_ids),
        }
    )


@router.delete("/scan/{tenant_id}/{scan_id}")
def delete_scan(
    tenant_id: str,
    scan_id: str,
    tenant_auth: tuple[str, str] = Depends(require_tenant_headers),
):
    header_tenant_id, header_api_token = tenant_auth
    enforce_tenant_match(tenant_id, header_tenant_id, "Path tenant_id")

    with SessionLocal() as db:
        tenant = load_authenticated_tenant(db, header_tenant_id, header_api_token)
        require_tenant_feature(db, tenant, "scan_sync")
        scan = db.scalar(select(Scan).where(Scan.tenant_id == tenant_id, Scan.scan_id == scan_id))

        if scan is None:
            return JSONResponse(content={"status": "not_found", "scan_id": scan_id})

        db.query(ScanIssueRecord).filter(ScanIssueRecord.scan_id == scan_id).delete()
        db.delete(scan)
        db.commit()

    return JSONResponse(content={"status": "deleted", "scan_id": scan_id})
