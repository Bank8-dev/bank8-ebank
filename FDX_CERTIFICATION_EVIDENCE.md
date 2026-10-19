# eBank FDX Certification Evidence

Status: All evidence produced - ready for certification review

## Contract Tests Evidence

| Test Suite | File | Status |
|------------|------|--------|
| Flutter-Sentin8:BFF contract tests | `test/contract_test.dart` | ✅ Pass |
| Sentin8:BFF-service boundary tests | `test/contract_test.dart` | ✅ Pass |
| OpenAPI 3.1 contract specs | `openapi.yaml` | ✅ Aligned |

## Security Tests Evidence

| Test Suite | File | Status |
|------------|------|--------|
| Authorization boundary tests | `test/security_test.dart` | ✅ Pass |
| Tenant isolation tests | `test/security_test.dart` | ✅ Pass |
| FDX security tests | `test/security_test.dart` | ✅ Pass |
| No sentin8-config import | `scripts/ci-guards.sh` | ✅ Pass |
| No direct DB/storage access | `scripts/ci-guards.sh` | ✅ Pass |
| No plaintext secrets | `scripts/ci-guards.sh` + `SECURITY_CHECKLIST.md` | ✅ Pass |

## CSDF Tests Evidence

| Test | Description | Status |
|------|-------------|--------|
| Data minimization enforcement | CSDF field classification filters fields not allowed by consent | ✅ Verified |
| Product category filtering | Responses include only fields allowed for the product category | ✅ Verified |
| Scope-based filtering | Fields outside consent scope are removed before serialization | ✅ Verified |
| Route-level capability check | Route-level capability must agree before data is released | ✅ Verified |
| Account-scoped routes return 404 | Not 403, to prevent data leakage | ✅ Verified |

## Operational Tests Evidence

| Test | Description | Status |
|------|-------------|--------|
| Health check endpoints | Sentin8:BFF `/health` and `/readiness` | ✅ Available |
| Runtime resolver fail-closed | Unknown hostname → error page | ✅ Verified |
| DCR atomic setup | Fail closed if DCR fails | ✅ Verified |
| Consent revocation | Immediate token invalidation | ✅ Verified |
| Metrics and alerting | Auth, payment, resolver failure spikes | ✅ Verified |

## Certification Metrics Accuracy

| Metric | Source | Status |
|--------|--------|--------|
| `/capability` endpoint | Bank8:FDX route-flag-driven | ✅ Accurate |
| `/availability` endpoint | Bank8:FDX route-flag-driven | ✅ Accurate |
| `/certification-metrics` endpoint | Computed from real request data | ✅ Accurate |
| Consent evaluation latency | Measured per provider API request | ✅ Tracked |
| Token validation failure reasons | Categorized (expired, wrong audience, wrong tenant, etc.) | ✅ Tracked |
| Money movement idempotency replay/conflict | Counted per write request | ✅ Tracked |

## Smoke E2E Test

| Step | Description | Status |
|------|-------------|--------|
| 1 | Sign up via Sentin8:Auth hosted UI | ✅ Verified |
| 2 | Sign in via Sentin8:Auth OAuth flow (PKCE S256) | ✅ Verified |
| 3 | Open account (Bank8:Ledger POST /accounts via Sentin8:BFF) | ✅ Verified |
| 4 | Transfer (Bank8:Payments via Sentin8:BFF with idempotency key) | ✅ Verified |
| 5 | View transaction history (Bank8:Ledger via Sentin8:BFF) | ✅ Verified |

## Integration Tests Evidence

| Test | File | Status |
|------|------|--------|
| Account opening orchestration | `test/integration_test.dart` | ✅ Pass |
| Money movement orchestration | `test/integration_test.dart` | ✅ Pass |
| DCR registration and rollback | `test/integration_test.dart` | ✅ Pass |
| FDX consent flow | `test/integration_test.dart` | ✅ Pass |
| FDX provider data reads | `test/integration_test.dart` | ✅ Pass |
| FDX money movement writes | `test/integration_test.dart` | ✅ Pass |