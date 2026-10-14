# eBank Security Verification Checklist
#
# This file documents the security verification steps for eBank.
# Each item must be verified before release.

## Token Security
- [ ] No OAuth access tokens on the Flutter client
- [ ] No OAuth refresh tokens on the Flutter client
- [ ] Sentin8:BFF holds all tokens server-side (encrypted in Valkey)
- [ ] Session token is opaque (no embedded claims)
- [ ] Token exchange happens server-side only

## Inter-Service Token Verification
- [ ] All Sentin8:BFF → Bank8:Ledger calls include Sentin8:Auth-issued access token
- [ ] All Sentin8:BFF → Bank8:Payments calls include Sentin8:Auth-issued access token
- [ ] All Sentin8:BFF → Bank8:FDX calls include Sentin8:Auth-issued access token
- [ ] All Sentin8:BFF → Sentin8:DB calls include Sentin8:Auth-issued access token
- [ ] All Sentin8:BFF → Sentin8:Storage calls include Sentin8:Auth-issued access token
- [ ] No unauthenticated requests accepted

## Sentin8:DB Table Compliance
- [ ] EBankCustomer includes org_id, env_id, id, created_at, updated_at, resource_version
- [ ] EBankProductEnrollment includes all mandatory system columns
- [ ] EBankTransferInstruction includes all mandatory system columns
- [ ] EBankStatementSnapshot includes all mandatory system columns
- [ ] EBankDocumentReference includes all mandatory system columns
- [ ] EBankOAuthClientRegistration includes all mandatory system columns
- [ ] EBankProviderProfile includes all mandatory system columns
- [ ] EBankRegisteredRecipient includes all mandatory system columns

## RLS Context
- [ ] RLS context set before every Sentin8:DB query (6 session variables)
- [ ] Production roles cannot disable RLS
- [ ] Missing RLS context fails closed
- [ ] No direct PostgreSQL access (all through Sentin8:DB API)

## Sentin8:Storage Compliance
- [ ] All object references use Sentin8:StorageObjectReference pattern
- [ ] Namespace model: environment or organization
- [ ] No raw storage credentials in Sentin8:DB rows
- [ ] All Sentin8:Storage access through HTTP API with Sentin8:Auth tokens

## No Direct Substrate Access
- [ ] No native PostgreSQL driver imports
- [ ] No raw SQL queries
- [ ] No ORM bypass
- [ ] No direct storage SDK usage

## Secret References
- [ ] No plaintext secrets in source code
- [ ] No plaintext secrets in configuration files
- [ ] OAuth client secrets stored as secret references
- [ ] API keys stored as secret references

## CI Guards
- [ ] CI detects native PostgreSQL drivers
- [ ] CI detects raw SQL
- [ ] CI detects ORM bypass
- [ ] CI detects direct storage SDK usage
- [ ] CI detects @sentin8/sentin8-config imports
- [ ] CI detects token-like strings in code
- [ ] CI detects direct backend service calls (bypassing Sentin8:BFF)