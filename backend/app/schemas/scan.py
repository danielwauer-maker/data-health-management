from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class QuickScanRequest(BaseModel):
    tenant_id: str
    metrics: Dict[str, int] = Field(default_factory=dict)


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
    estimated_impact_eur: float = Field(default=0, ge=0)


class QuickScanResponse(BaseModel):
    scan_id: str
    scan_type: str = "quick"
    generated_at_utc: datetime
    data_score: int = Field(ge=0, le=100)
    checks_count: int = Field(ge=0)
    issues_count: int = Field(ge=0)
    premium_available: bool = True
    estimated_loss_eur: float = Field(default=0, ge=0)
    potential_saving_eur: float = Field(default=0, ge=0)
    summary: ScanSummary
    issues: List[ScanIssue] = Field(default_factory=list)


class ScanHistoryEntry(BaseModel):
    scan_id: str
    scan_type: str
    generated_at_utc: datetime
    data_score: int
    checks_count: int
    issues_count: int
    premium_available: bool
    estimated_loss_eur: float = Field(default=0, ge=0)
    potential_saving_eur: float = Field(default=0, ge=0)
    summary: ScanSummary
    issues: List[ScanIssue] = Field(default_factory=list)


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
