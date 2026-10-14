// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank savings & deposit products page — US Checking, US Savings, Shariah, Time Deposit, Wallet.
// Savings/deposit product views.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

class SavingsProductsPage extends StatefulWidget {
  final EBankContext appContext;

  const SavingsProductsPage({super.key, required this.appContext});

  @override
  State<SavingsProductsPage> createState() => _SavingsProductsPageState();
}

class _SavingsProductsPageState extends State<SavingsProductsPage> {
  List<dynamic> _depositAccounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDepositAccounts();
  }

  Future<void> _loadDepositAccounts() async {
    try {
      final response = await widget.appContext.services!.ledger.get('/v1/accounts');
      if (response.isSuccess && response.data != null) {
        final accounts = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .where((a) => _isDepositType(a))
                .toList() ??
            [];
        setState(() {
          _depositAccounts = accounts;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  bool _isDepositType(Map<String, dynamic> account) {
    final type = (account['accountType'] ?? account['productType'] ?? '').toString().toUpperCase();
    return type.contains('CHECKING') ||
        type.contains('SAVINGS') ||
        type.contains('DEPOSIT') ||
        type.contains('WALLET') ||
        type.contains('SHARIAH');
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
            const Text('Savings & Deposits', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.sm),
            const Text(
              'US Checking, US Savings, Shariah Savings, Time Deposit, Wallet',
              style: Sentin8Text.bodyMedium,
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            if (_depositAccounts.isEmpty)
              const GlassPanel(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.savings_outlined, size: 48, color: Sentin8Colors.textSecondary),
                      SizedBox(height: Sentin8Spacing.md),
                      Text('No savings/deposit products yet', style: Sentin8Text.headlineMedium),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _depositAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _depositAccounts[index] as Map<String, dynamic>;
                    return _buildDepositCard(account);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositCard(Map<String, dynamic> account) {
    final type = (account['accountType'] ?? account['productType'] ?? '').toString();
    final name = account['nickname'] ?? account['name'] ?? type;
    final balance = (account['currentBalance'] ?? account['balance'] ?? 0) as num;
    final rate = account['interestRate'];

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
                Text('\$${balance.toDouble().toStringAsFixed(2)}', style: Sentin8Text.bodyLarge),
              ],
            ),
            if (rate != null) ...[
              const SizedBox(height: Sentin8Spacing.xs),
              if (type.toUpperCase().contains('SHARIAH'))
                Text('Expected Profit Rate: $rate%', style: Sentin8Text.labelSmall)
              else
                Text('Interest Rate: $rate%', style: Sentin8Text.labelSmall),
            ],
            if (type.toUpperCase().contains('TIME_DEPOSIT')) ...[
              const SizedBox(height: Sentin8Spacing.xs),
              Text('Maturity: ${account['maturityDate'] ?? 'N/A'}', style: Sentin8Text.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toUpperCase();
    if (t.contains('WALLET')) return Icons.account_balance_wallet;
    if (t.contains('DEPOSIT')) return Icons.lock_clock;
    if (t.contains('CHECKING')) return Icons.payment;
    return Icons.savings;
  }
}