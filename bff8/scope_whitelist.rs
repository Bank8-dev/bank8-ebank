// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank BFF scope whitelist configuration
// BFF scope whitelist per app instance.
//
// Consumed by Sentin8:BFF at client registration time: an app instance may
// request scopes through DCR only within this whitelist.
//
// This file documents the BFF scope whitelist for eBank instances.
// The shared BFF server enforces scope prefixes per proxy service.
// BFF scope enforcement: has_scope(scopes, "bank8:ledger:") matches any scope
// starting with "bank8:ledger:" (e.g. bank8:ledger:read, bank8:ledger:write).
//
// This configuration is applied during App setup when the BFF OAuth
// client is registered via DCR.

/// ScopeWhitelist defines the allowed scopes and services for eBank BFF instances.
/// These are requested during DCR and enforced by BFF on every proxy request.
#[derive(Debug, Clone)]
pub struct ScopeWhitelist {
    pub app_slug: String,
    pub allowed_scopes: Vec<String>,
    pub allowed_services: Vec<String>,
}

/// E_BANK_SCOPE_WHITELIST is the canonical scope whitelist for all eBank instances.
/// The eBank scope whitelist (per the README/DESIGN.md scope manifest).
pub static E_BANK_SCOPE_WHITELIST: ScopeWhitelist = ScopeWhitelist {
    app_slug: "ebank".to_string(),
    allowed_scopes: vec![
        "openid".to_string(),
        "profile".to_string(),
        "email".to_string(),
        "bank8:ledger:accounts:read".to_string(),
        "bank8:ledger:accounts:write".to_string(),
        "bank8:ledger:products:read".to_string(),
        "bank8:ledger:postings:read".to_string(),
        "bank8:ledger:postings:write".to_string(),
        "bank8:ledger:balances:read".to_string(),
        "bank8:payments:instructions:read".to_string(),
        "bank8:payments:instructions:write".to_string(),
        "bank8:payments:payments:read".to_string(),
        "bank8:payments:payments:write".to_string(),
        "bank8:payments:routing:read".to_string(),
        "openfin8:ca:provider:read".to_string(),
        "openfin8:ca:provider:write".to_string(),
        "openfin8:ca:admin".to_string(),
        "db:data:read".to_string(),
        "db:data:write".to_string(),
        "storage:env:read".to_string(),
        "storage:env:write".to_string(),
    ],
    allowed_services: vec![
        "ledger".to_string(),
        "payments".to_string(),
        "fdx".to_string(),
        "db".to_string(),
        "storage".to_string(),
    ],
};