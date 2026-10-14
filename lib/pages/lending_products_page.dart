// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank lending product pages — loan, credit card, mortgage, LOC, BNPL, home loan redraw.
// Lending product views (loan, credit card, mortgage, LOC, BNPL, home-loan redraw).
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

/// Lending products page — displays all lending-type products.
/// Each product card opens a detail view specific to that product type.
class LendingProductsPage extends StatefulWidget {
  final EBankContext appContext;

  const LendingProductsPage({super.key, required this.appContext});

  @override
  State<LendingProductsPage> createState() => _LendingProductsState();
}

class _LendingProductsState extends State<LendingProductsPage> {
  List<dynamic> _lendingAccounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLendingAccounts();
  }

  Future<void> _loadLendingAccounts() async {
    try {
      final response = await widget.appContext.services!.ledger.get('/v1/accounts');
      if (response.isSuccess && response.data != null) {
        final accounts = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .where((a) => _isLendingType(a))
                .toList() ??
            [];
        setState(() {
          _lendingAccounts = accounts;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  bool _isLendingType(Map<String, dynamic> account) {
    final type = (account['accountType'] ?? account['productType'] ?? '').toString().toUpperCase();
    return type.contains('LOAN') ||
        type.contains('CREDIT_CARD') ||
        type.contains('MORTGAGE') ||
        type.contains('LINE_OF_CREDIT') ||
        type.contains('BNPL') ||
        type.contains('REDRAW');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Sentin8Colors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: Padding(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lending Products', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.sm),
            const Text(
              'Loan, Credit Card, Mortgage, Line of Credit, BNPL, Home Loan Redraw',
              style: Sentin8Text.bodyMedium,
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            if (_lendingAccounts.isEmpty)
              const GlassPanel(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_outlined, size: 48, color: Sentin8Colors.textSecondary),
                      SizedBox(height: Sentin8Spacing.md),
                      Text('No lending products yet', style: Sentin8Text.headlineMedium),
                      SizedBox(height: Sentin8Spacing.xs),
                      Text('Open a product from the Products catalog.', style: Sentin8Text.bodyMedium),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _lendingAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _lendingAccounts[index] as Map<String, dynamic>;
                    return _buildLendingCard(account);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLendingCard(Map<String, dynamic> account) {
    final type = (account['accountType'] ?? account['productType'] ?? '').toString();
    final name = account['nickname'] ?? account['name'] ?? type;
    final balance = (account['currentBalance'] ?? account['balance'] ?? 0) as num;
    final limit = account['creditLimit'] as num?;
    final utilization = limit != null && limit.toDouble() > 0
        ? (balance.toDouble() / limit.toDouble() * 100).round()
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.sm),
      child: GlassPanel(
        padding: const EdgeInsets.all(Sentin8Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForType(type), color: Sentin8Colors.primary),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name as String, style: Sentin8Text.bodyLarge),
                      Text(type, style: Sentin8Text.labelSmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${balance.toDouble().toStringAsFixed(2)}', style: Sentin8Text.bodyLarge),
                    if (account['status'] != null)
                      Text(account['status'].toString(), style: Sentin8Text.labelSmall),
                  ],
                ),
              ],
            ),
            if (limit != null) ...[
              const SizedBox(height: Sentin8Spacing.sm),
              Row(
                children: [
                  Text('Limit: \$${limit.toDouble().toStringAsFixed(0)}', style: Sentin8Text.labelSmall),
                  if (utilization != null) ...[
                    const SizedBox(width: Sentin8Spacing.md),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (utilization / 100).clamp(0, 1),
                        backgroundColor: Sentin8Colors.surfaceDark,
                        color: utilization > 80 ? Sentin8Colors.warning : Sentin8Colors.primary,
                      ),
                    ),
                    const SizedBox(width: Sentin8Spacing.sm),
                    Text('$utilization%', style: Sentin8Text.labelSmall),
                  ],
                ],
              ),
            ],
            if (type.toUpperCase().contains('LOAN') && !type.toUpperCase().contains('CREDIT')) ...[
              const SizedBox(height: Sentin8Spacing.sm),
              Text('Next Payment: ${account['nextPaymentDate'] ?? 'N/A'}', style: Sentin8Text.labelSmall),
              if (account['nextPaymentAmount'] != null)
                Text('Amount: \$${account['nextPaymentAmount']}', style: Sentin8Text.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toUpperCase();
    if (t.contains('CREDIT_CARD')) return Icons.credit_card;
    if (t.contains('MORTGAGE')) return Icons.home;
    if (t.contains('LOAN')) return Icons.request_quote;
    if (t.contains('BNPL')) return Icons.shopping_bag;
    return Icons.account_balance;
  }
}