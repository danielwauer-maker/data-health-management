from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class DataProfile(BaseModel):
    customers: int = Field(default=0, ge=0)
    vendors: int = Field(default=0, ge=0)
    items: int = Field(default=0, ge=0)
    customer_ledger_entries: int = Field(default=0, ge=0)
    vendor_ledger_entries: int = Field(default=0, ge=0)
    item_ledger_entries: int = Field(default=0, ge=0)
    sales_headers: int = Field(default=0, ge=0)
    sales_lines: int = Field(default=0, ge=0)
    purchase_headers: int = Field(default=0, ge=0)
    purchase_lines: int = Field(default=0, ge=0)
    gl_entries: int = Field(default=0, ge=0)
    value_entries: int = Field(default=0, ge=0)
    warehouse_entries: int = Field(default=0, ge=0)
    total_records: int = Field(default=0, ge=0)


class QuickScanRequest(BaseModel):
    tenant_id: str
    metrics: Dict[str, int] = Field(default_factory=dict)
    data_profile: DataProfile = Field(default_factory=DataProfile)


class ScanSummary(BaseModel):
    headline: str
    rating: str


class ScanIssue(BaseModel):
    code: str
    title: str
    severity: str
    affected_count: int = Field(ge=0)
    premium_only: bool = False
    recommendation_preview: Optional[str] = None
    estimated_impact_eur: float = Field(default=0.0, ge=0)


class QuickScanResponse(BaseModel):
    scan_id: str
    scan_type: str = "quick"
    generated_at_utc: datetime
    data_score: int = Field(ge=0, le=100)
    checks_count: int = Field(ge=0)
    issues_count: int = Field(ge=0)
    premium_available: bool = True
    summary: ScanSummary
    issues: List[ScanIssue] = Field(default_factory=list)
    data_profile: DataProfile = Field(default_factory=DataProfile)
    estimated_loss_eur: float = Field(default=0.0, ge=0)
    potential_saving_eur: float = Field(default=0.0, ge=0)
    estimated_premium_price_monthly: float = Field(default=0.0, ge=0)
    roi_eur: float = 0.0


class ScanHistoryEntry(BaseModel):
    scan_id: str
    scan_type: str
    generated_at_utc: datetime
    data_score: int
    checks_count: int
    issues_count: int
    premium_available: bool
    summary: ScanSummary
    issues: List[ScanIssue] = Field(default_factory=list)
    data_profile: DataProfile = Field(default_factory=DataProfile)
    estimated_loss_eur: float = Field(default=0.0, ge=0)
    potential_saving_eur: float = Field(default=0.0, ge=0)
    estimated_premium_price_monthly: float = Field(default=0.0, ge=0)
    roi_eur: float = 0.0


class ScanHistoryResponse(BaseModel):
    tenant_id: str
    scans: List[ScanHistoryEntry] = Field(default_factory=list)


class ScanTrendResponse(BaseModel):
    tenant_id: str
    latest_scan_id: str | None = None
    previous_scan_id: str | None = None
    latest_score: int | None = None
    previous_score: int | None = None
    delta: int | None = None
    trend: str = "same"
