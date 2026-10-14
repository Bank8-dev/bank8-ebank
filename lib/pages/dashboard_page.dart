// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

/// Parse a balance value from an account map. The Ledger API returns
/// `currentBalance` as a string in minor units (e.g. "50000" = $500.00).
/// This helper handles both string and numeric values and converts
/// to major units for display.
double _parseBalance(Map<String, dynamic> account) {
  final val = account['currentBalance'] ?? account['current_balance'] ?? account['balance'];
  if (val == null) return 0;
  double minor;
  if (val is num) {
    minor = val.toDouble();
  } else if (val is String) {
    minor = double.tryParse(val) ?? 0;
  } else {
    return 0;
  }
  // Convert minor units to major units (e.g. 50000 cents → 500.00)
  return minor / 100;
}

/// Customer dashboard — shows account overview, balances, alerts.
/// Dashboard — accounts overview with balances
///
/// Data is fetched via BFF → Ledger API (proxy route /proxy/ledger/...)
class DashboardPage extends StatefulWidget {
  final EBankContext appContext;
  final ValueChanged<String>? onNavigate;

  const DashboardPage({super.key, required this.appContext, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response =
          await widget.appContext.services!.ledger.get('/v1/accounts');
      if (response.isSuccess && response.data != null) {
        // Bare JSON arrays from services (Ledger, Payments, FDX, etc.) are
        // wrapped under 'data' by BffApiClient.  See services.dart.
        final accountsRaw = response.data!['data'] as List<dynamic>? ?? [];
        setState(() {
          _accounts = accountsRaw;
          _loading = false;
        });
      } else {
        // No accounts yet or error
        setState(() {
          _accounts = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: Padding(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: Sentin8Colors.primary))
            else if (_error != null)
              GlassPanel(
                child: Text('Error loading accounts: $_error',
                    style: const TextStyle(color: Sentin8Colors.error)),
              )
            else ...[
              _buildTotalBalance(),
              const SizedBox(height: Sentin8Spacing.lg),
              _buildAccountList(),
              const SizedBox(height: Sentin8Spacing.lg),
              _buildQuickActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalance() {
    double total = 0;
    for (final account in _accounts) {
      final balance = _parseBalance(account);
      total += balance;
    }

    return GlassPanel(
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Sentin8Colors.primary, size: 32),
          const SizedBox(width: Sentin8Spacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Balance', style: Sentin8Text.labelSmall),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: Sentin8Text.headlineLarge,
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Sentin8Colors.textSecondary),
            onPressed: _loadAccounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList() {
    if (_accounts.isEmpty) {
      return GlassPanel(
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: Sentin8Colors.textSecondary),
            SizedBox(height: Sentin8Spacing.md),
            Text('No accounts yet', style: Sentin8Text.headlineMedium),
            SizedBox(height: Sentin8Spacing.sm),
            Text('Open a product to get started.', style: Sentin8Text.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Accounts', style: Sentin8Text.headlineMedium),
        const SizedBox(height: Sentin8Spacing.md),
        ..._accounts.map((account) => _buildAccountCard(account)),
      ],
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final productType = account['productType'] as String? ??
        account['accountType'] as String? ??
        '';
    final name = account['nickname'] as String? ??
        account['name'] as String? ??
        _prettyProductType(productType);
    final type = _prettyProductType(productType);
    final denom = account['denomination'] as String? ?? 'CAD';
    final balance = _parseBalance(account);
    final status = account['status'] as String? ?? 'OPEN';

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.sm),
      child: Semantics(
        label: name,
        child: GlassPanel(
          padding: const EdgeInsets.all(Sentin8Spacing.md),
          child: Row(
            children: [
              Icon(productIconForType(productType),
                  color: Sentin8Colors.primary),
              const SizedBox(width: Sentin8Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Sentin8Text.bodyLarge),
                    Text('$type · $denom', style: Sentin8Text.labelSmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${balance.toDouble().toStringAsFixed(2)}',
                      style: Sentin8Text.bodyLarge),
                  Text(status, style: Sentin8Text.labelSmall),
                ],
              ),
            ],
          ),
        ), // GlassPanel
      ), // Semantics
    );
  }

  /// Pretty-print a product type into a human-readable account name.
  /// Ledger accounts don't carry a name/nickname field, so we derive a
  /// readable label from the productType.
  String _prettyProductType(String type) {
    return switch (type) {
      'current_account' => 'Checking Account',
      'savings_account' => 'Savings Account',
      'us_checking' => 'US Checking',
      'us_savings' => 'US Savings',
      'shariah_savings' => 'Shariah Savings',
      'time_deposit' => 'Time Deposit',
      'loan' => 'Loan Account',
      'credit_card' => 'Credit Card',
      'mortgage' => 'Mortgage',
      'line_of_credit' => 'Line of Credit',
      'wallet' => 'Wallet',
      'bnpl' => 'BNPL',
      'home_loan_redraw' => 'Home Loan Redraw',
      _ => 'Account',
    };
  }

  Widget _buildQuickActions() {
    void goTo(String route) {
      if (widget.onNavigate != null) {
        widget.onNavigate!(route);
      } else {
        Navigator.pushNamed(context, route);
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.swap_horiz,
            label: 'Transfer',
            onTap: () => goTo('/transfers'),
          ),
        ),
        const SizedBox(width: Sentin8Spacing.sm),
        Expanded(
          child: _buildActionCard(
            icon: Icons.add_circle_outline,
            label: 'Open Account',
            onTap: () => goTo('/products'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: GlassPanel(
        padding: const EdgeInsets.all(Sentin8Spacing.md),
        child: Column(
          children: [
            Icon(icon, color: Sentin8Colors.primary),
            const SizedBox(height: Sentin8Spacing.xs),
            Text(label, style: Sentin8Text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
