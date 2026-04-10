# Session 2 - Feature-Flag Foundation

This document defines the single source of truth for entitlement resolution.

Goal: one canonical mapping from `plan` + `license_status` to `features`.

## 1) Current state (observed)

- Backend currently resolves `deep_scan` as shared analysis basis for active/trial access.
- BC extension currently derives premium in two ways:
  - from `plan` + `license_status`
  - from premium action/detail features (`Premium Enabled`)
- This creates conflicting behavior between UI visibility and action gating.

## 2) Canonical entitlement contract (target)

Only backend resolves entitlements. Every consumer (dashboard, extension, admin UI) reads the same output.

### 2.1 License status contract

- `trial`: temporary access period
- `active`: paid access
- `blocked`: payment/problem state, account exists but premium actions must be disabled
- `expired`: no active/trial entitlement

### 2.2 Plan contract

- `free`
- `premium`

No other plan codes are part of the canonical contract.

### 2.3 Feature keys (canonical set)

- `scan_sync`
- `quick_scan`
- `deep_scan`
- `advanced_checks`
- `recommendations`
- `record_drilldown`
- `correction_worklists`
- `analytics_full`
- `billing_checkout`
- `billing_portal`

## 3) Entitlement matrix (target)

Legend: `Y` enabled, `N` disabled.

| plan | license_status | scan_sync | quick_scan | deep_scan | advanced_checks | recommendations | record_drilldown | correction_worklists | analytics_full | billing_checkout | billing_portal |
|---|---|---|---|---|---|---|---|---|---|---|---|
| free | trial | Y | Y | Y | N | N | N | N | N | Y | N |
| free | active | Y | Y | Y | N | N | N | N | N | Y | N |
| free | blocked | Y | Y | N | N | N | N | N | N | Y | N |
| free | expired | Y | Y | N | N | N | N | N | N | Y | N |
| premium | trial | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| premium | active | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| premium | blocked | Y | Y | N | N | N | N | N | N | Y | Y |
| premium | expired | Y | Y | N | N | N | N | N | N | Y | Y |

Notes:
- `quick_scan` remains available for all states to keep baseline product usable.
- `deep_scan` is part of the shared analysis basis for free and premium during active/trial access.
- Premium-only capabilities are disabled for `blocked`/`expired`.
- `billing_checkout` remains available to allow upgrade/recovery.
- `billing_portal` remains available for premium lifecycle self-service.

## 4) API output contract (`/license/status`)

Required fields:

- `tenant_id` (string)
- `plan` (`free` | `premium`)
- `license_status` (`trial` | `active` | `blocked` | `expired`)
- `features` (string array, derived only from this matrix)

Optional (recommended for future-proofing):

- `entitlement_version` (integer/string)
- `resolved_at_utc` (timestamp)

## 4.1 `premium_available` semantics

`premium_available` in scan payloads/responses is a derived compatibility flag and means:

- `true` when premium action/detail features are present in tenant features
- `false` otherwise

It must not be treated as an independent source of truth.
Source of truth remains `/license/status.features`.

## 5) Implementation checklist (next steps)

1. Move feature resolution into one backend service function:
   - input: normalized `plan`, `license_status`
   - output: exact feature set from matrix
2. Make `/license/status` use only this resolver.
3. Remove/stop using extension heuristic:
   - no premium derivation from `deep_scan` presence
4. Replace extension gating checks with matrix-driven feature checks.
5. Ensure dashboard/API paths enforce backend entitlement server-side (not only UI).
6. Add integration tests for all matrix rows.
7. Keep a lightweight matrix validator script for CI/local sanity checks.

## 6) Acceptance criteria for Session 2

- One canonical resolver function exists in backend.
- No alternate premium heuristics remain in extension/web.
- `/license/status` feature output exactly matches matrix.
- At least one automated test per matrix row (or equivalent parametrized suite).
