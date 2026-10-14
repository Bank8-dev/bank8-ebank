// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';
import '../url_router.dart';
import 'account_detail_page.dart';

/// Parse a balance value from an account map (handles string/num, converts minor→major).
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
  return minor / 100;
}

/// Account list page — shows all customer accounts with navigation to detail.
/// Account list screen with navigation to detail.
class AccountListPage extends StatefulWidget {
  final EBankContext appContext;

  const AccountListPage({super.key, required this.appContext});

  @override
  State<AccountListPage> createState() => _AccountListPageState();
}

class _AccountListPageState extends State<AccountListPage> {
  List<dynamic> _accounts = [];
  bool _loading = true;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final response =
          await widget.appContext.services!.ledger.get('/v1/accounts');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _accounts = response.data!['data'] as List<dynamic>? ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _accounts = [];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _accounts = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Sentin8Colors.primary)),
      );
    }

    // If an account is selected, show the detail page inline (keeping
    // the sidebar visible).
    if (_selectedAccountId != null) {
      return AccountDetailPage(
        appContext: widget.appContext,
        accountId: _selectedAccountId!,
        onBack: () {
          setState(() => _selectedAccountId = null);
          navigateTo('/accounts');
        },
      );
    }

    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: Padding(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Accounts', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            if (_accounts.isEmpty)
              const GlassPanel(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: Sentin8Colors.textSecondary),
                      SizedBox(height: Sentin8Spacing.md),
                      Text('No accounts yet', style: Sentin8Text.headlineMedium),
                    ],
                  ),
                ),
              )
            else
              // The shell wraps this page in a SingleChildScrollView with a
              // minHeight constraint, so the vertical space is unbounded.
              // Use shrinkWrap + NeverScrollableScrollPhysics so the list
              // lays out inside the scroll view without requiring an
              // Expanded (which would assert with infinite height).
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index] as Map<String, dynamic>;
                  final productType = account['productType'] as String? ?? '';
                  final name = account['nickname'] as String? ??
                      account['name'] as String? ??
                      _prettyProductType(productType);
                  final type = productType.isNotEmpty
                      ? _prettyProductType(productType)
                      : (account['accountType'] as String? ?? '');
                  final denom = account['denomination'] as String? ?? 'CAD';
                  final balance = _parseBalance(account);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: Sentin8Spacing.sm),
                    child: Semantics(
                      label: name,
                      child: GestureDetector(
                        onTap: () {
                          final accountId = account['id'] as String? ?? '';
                          if (accountId.isNotEmpty) {
                            setState(() => _selectedAccountId = accountId);
                            pushRoute('/accounts/$accountId');
                          }
                        },
                        child: GlassPanel(
                          padding: const EdgeInsets.all(Sentin8Spacing.md),
                          child: ListTile(
                            leading: Icon(
                                productIconForType(productType),
                                color: Sentin8Colors.primary),
                            title: Text(name, style: Sentin8Text.bodyLarge),
                            subtitle: Text('$type · $denom',
                                style: Sentin8Text.labelSmall),
                            trailing: Text(
                              '\$${balance.toDouble().toStringAsFixed(2)}',
                              style: Sentin8Text.bodyLarge,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
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
}
