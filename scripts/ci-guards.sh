#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
# SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
# SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
# SPDX-License-Identifier: Apache-2.0
# eBank CI Guard — detect prohibited patterns in eBank code.
#
# This script scans all eBank source files for patterns that violate
# Sentin8 architecture principles. Any violation causes CI to fail.
set -euo pipefail

EBANK_DIR="$(cd "$(dirname "$0")" && pwd)"
VIOLATIONS=0

echo "🔍 Running eBank CI guards..."

# Check 1: No direct PostgreSQL drivers (should use Sentin8:DB API only)
if grep -r --include='*.dart' --include='*.rs' -l 'postgres\|pgx\|tokio-postgres\|diesel\|sqlx::PgPool\|PgPoolOptions' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: Direct PostgreSQL driver usage detected. All DB access must go through Sentin8:DB API."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 2: No raw SQL queries
if grep -r --include='*.dart' --include='*.rs' -l 'SELECT.*FROM\|INSERT.*INTO\|UPDATE.*SET\|DELETE.*FROM' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: Raw SQL queries detected. All persistence through Sentin8:DB HTTP API."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 3: No ORM bypass
if grep -r --include='*.dart' --include='*.rs' -l 'diesel\|sea-orm\|sqlx\|rbatis\|ormx' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: ORM usage detected. All persistence through Sentin8:DB HTTP API."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 4: No direct storage SDK usage (should use Sentin8:Storage API only)
if grep -r --include='*.dart' --include='*.rs' -l 'aws-sdk-rust\|aws-sdk-s3\|minio-rs\|cloud-storage\|azure-storage\|reqwest.*s3\|S3Client' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: Direct object storage SDK usage detected. All object storage through Sentin8:Storage API."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 5: No @sentin8/sentin8-config import
if grep -r --include='*.dart' --include='*.rs' -l 'sentin8-config\|sentin8_config' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: @sentin8/sentin8-config import detected. Third-party apps must NOT import platform config."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 6: No token-like strings in code (JWT patterns, bearer tokens)
if grep -r --include='*.dart' --include='*.rs' -l 'eyJ[A-Za-z0-9_-]*\.eyJ' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: JWT-like string detected in source code. Never hardcode tokens."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 7: No direct external HTTP calls (should go through Sentin8:BFF)
if grep -r --include='*.dart' -l 'ledger\.sentin8\.local\|payments\.sentin8\.local\|fdx\.sentin8\.local\|db\.sentin8\.local\|storage\.sentin8\.local' "$EBANK_DIR/lib" 2>/dev/null | grep -v 'test/'; then
  echo "❌ VIOLATION: Direct backend service call detected. All calls must go through Sentin8:BFF proxy."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check 8: No plaintext secrets in source
if grep -r --include='*.dart' --include='*.rs' --include='*.yaml' --include='*.json' -l 'password\s*[:=]\s*["\x27][^"\x27]' "$EBANK_DIR/lib" "$EBANK_DIR/bff" 2>/dev/null; then
  echo "❌ VIOLATION: Plaintext password/secret detected. Use secret references only."
  VIOLATIONS=$((VIOLATIONS + 1))
fi

if [ $VIOLATIONS -gt 0 ]; then
  echo ""
  echo "❌ $VIOLATIONS CI guard violation(s) found. Fix before merging."
  exit 1
fi

echo "✅ All CI guards passed. No prohibited patterns detected."