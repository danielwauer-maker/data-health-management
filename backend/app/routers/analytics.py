# analytics.py (simplified with module score logic)
import math
from typing import Any, List, Dict

SEVERITY_WEIGHTS = {"high": 8.0, "medium": 3.5, "low": 1.25}

MODULE_ORDER = [
    "System","Finance","Sales","Purchasing","Inventory",
    "CRM","Manufacturing","Service","Jobs","HR"
]

MODULE_RELEVANCE = {
    "System":1.0,"Finance":1.15,"Sales":1.0,"Purchasing":0.95,
    "Inventory":1.05,"CRM":0.9,"Manufacturing":1.0,
    "Service":0.9,"Jobs":0.9,"HR":0.85,
}

GLOBAL_MODULE_WEIGHTS = {
    "System":1.10,"Finance":1.20,"Sales":1.00,"Purchasing":0.95,
    "Inventory":1.05,"CRM":0.90,"Manufacturing":1.00,
    "Service":0.90,"Jobs":0.85,"HR":0.80,
}

def _safe_int(v): return int(v or 0)

def _normalize_severity(s):
    s = (s or "").lower()
    if "high" in s: return "high"
    if "medium" in s: return "medium"
    return "low"

def _issue_group_from_code(code: str) -> str:
    c = (code or "").upper()
    if c.startswith("EMPLOYEE") or c.startswith("RESOURCE"): return "HR"
    if c.startswith("JOB"): return "Jobs"
    if c.startswith("SERVICE") or c.startswith("SERV_"): return "Service"
    if c.startswith("MFG") or c.startswith("PROD") or c.startswith("BOM") or c.startswith("ROUTING"): return "Manufacturing"
    if c.startswith("SALES"): return "Sales"
    if c.startswith("PURCHASE") or c.startswith("VENDOR"): return "Purchasing"
    if c.startswith("ITEM") or c.startswith("INVENTORY"): return "Inventory"
    if "LEDGER" in c or c.startswith("GL"): return "Finance"
    if c.startswith("CUSTOMER"): return "CRM"
    return "System"

def _score_variant(score: int) -> str:
    if score <= 60: return "critical"
    if score <= 75: return "warning"
    if score <= 85: return "moderate"
    if score <= 95: return "good"
    return "excellent"

def _issue_penalty(issue):
    sev = _normalize_severity(issue["severity"])
    weight = SEVERITY_WEIGHTS.get(sev,1.25)
    affected = max(0,_safe_int(issue["affected_count"]))
    module = _issue_group_from_code(issue["code"])
    relevance = MODULE_RELEVANCE.get(module,1.0)
    count_factor = min(4.0, math.log10(affected+1)+0.3)
    return module, weight*count_factor*relevance

def build_module_scores(issues: List[Dict[str,Any]]):
    penalties = {m:0.0 for m in MODULE_ORDER}
    for i in issues:
        m,p = _issue_penalty(i)
        penalties[m]+=p
    result=[]
    for m in MODULE_ORDER:
        score=max(0,round(100-penalties[m]))
        result.append({"name":m,"score":score,"variant":_score_variant(score)})
    return result

def build_global_score(module_scores):
    total=0; wsum=0
    for m in module_scores:
        w=GLOBAL_MODULE_WEIGHTS.get(m["name"],1.0)
        total+=m["score"]*w
        wsum+=w
    return round(total/wsum) if wsum else 100
