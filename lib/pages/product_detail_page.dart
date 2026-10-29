// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank product detail page - product details with account opening form.
// Shows key product info, asks necessary questions (currency, account name),
// then opens the account via Ledger POST /v1/accounts.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

class ProductDetailPage extends StatefulWidget {
  final EBankContext appContext;
  final Map<String, dynamic> product;
  final VoidCallback? onBack;

  const ProductDetailPage({
    super.key,
    required this.appContext,
    required this.product,
    this.onBack,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _opening = false;
  final _accountNameController = TextEditingController();
  String _currency = 'CAD';

  @override
  void initState() {
    super.initState();
    final params = (widget.product['parameters'] as Map<String, dynamic>?) ?? {};
    _currency = params['denomination'] as String? ?? 'CAD';
    // Default the nickname to the product name so the user has a
    // sensible starting point (e.g. "iBank Checking"). They can
    // overwrite it (e.g. "My Travel Checking") or clear it to be
    // required to type one.
    final productName = widget.product['name'] as String? ??
        widget.product['productName'] as String? ??
        '';
    _accountNameController.text = productName;
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _openAccount() async {
    if (_accountNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an account name')),
      );
      return;
    }

    setState(() => _opening = true);

    try {
      // Ensure a Ledger customer row exists before opening an account.
      // Only eBank calls this - the app decides which services it needs.
      await widget.appContext.ensureLedgerCustomer();

      final productType = widget.product['productType'] ?? widget.product['type'] ?? '';
      final productId = widget.product['id'] ?? '';

      final response = await widget.appContext.services!.ledger.post(
        '/v1/accounts',
        body: {
          'product_id': productId,
          'product_type': productType,
          'account_type': 'customer',
          'denomination': _currency,
          'nickname': _accountNameController.text.trim(),
        },
      );

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account opened successfully!')),
          );
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.pop(context);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open account: ${response.error ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final name = product['name'] as String? ?? product['productName'] as String? ?? 'Product';
    final type = product['productType'] as String? ?? product['type'] as String? ?? '';
    final params = (product['parameters'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: Padding(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button + title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Sentin8Colors.primary),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(child: Text(name, style: Sentin8Text.headlineLarge)),
              ],
            ),
            const SizedBox(height: Sentin8Spacing.lg),

            // Product key info
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Sentin8Spacing.sm, vertical: Sentin8Spacing.xs),
                      decoration: BoxDecoration(
                        color: Sentin8Colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_prettyType(type), style: const TextStyle(color: Sentin8Colors.primary, fontSize: 12)),
                    ),
                  const SizedBox(height: Sentin8Spacing.md),
                  ..._keyInfoEntries(type, params).map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
                    child: Row(
                      children: [
                        SizedBox(width: 180, child: Text(entry.$1, style: Sentin8Text.labelSmall)),
                        Expanded(child: Text(entry.$2, style: Sentin8Text.bodyMedium)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: Sentin8Spacing.lg),

            // Account opening form
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Open Account', style: Sentin8Text.headlineMedium),
                  const SizedBox(height: Sentin8Spacing.md),

                  // Account name field - pre-filled with the product name
                  // as a sensible default. The customer can keep, edit,
                  // or clear it; clearing makes it required (enforced in
                  // _openAccount).
                  const Text('Account Name (Nickname)', style: Sentin8Text.labelSmall),
                  const SizedBox(height: Sentin8Spacing.xs),
                  TextField(
                    controller: _accountNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. My Travel Checking',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: Sentin8Spacing.md),

                  // Currency selector
                  const Text('Currency', style: Sentin8Text.labelSmall),
                  const SizedBox(height: Sentin8Spacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CAD', child: Text('CAD - Canadian Dollar')),
                      DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP - British Pound')),
                      DropdownMenuItem(value: 'AUD', child: Text('AUD - Australian Dollar')),
                      DropdownMenuItem(value: 'AED', child: Text('AED - UAE Dirham')),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'CAD'),
                  ),
                  const SizedBox(height: Sentin8Spacing.lg),

                  // Open Account button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _opening ? null : _openAccount,
                      child: _opening
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Open Account'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyType(String type) {
    return switch (type) {
      'current_account' => 'Current Account',
      'savings_account' => 'Savings Account',
      'us_checking' => 'US Checking',
      'us_savings' => 'US Savings',
      'shariah_savings' => 'Shariah Savings',
      'time_deposit' => 'Time Deposit',
      'loan' => 'Loan',
      'credit_card' => 'Credit Card',
      'mortgage' => 'Mortgage',
      'line_of_credit' => 'Line of Credit',
      'wallet' => 'Wallet',
      'bnpl' => 'BNPL',
      'home_loan_redraw' => 'Home Loan Redraw',
      _ => type,
    };
  }

  List<(String, String)> _keyInfoEntries(String type, Map<String, dynamic> params) {
    final info = <(String, String)>[];
    info.add(('Currency', params['denomination'] as String? ?? 'CAD'));

    switch (type) {
      case 'current_account':
      case 'savings_account':
      case 'us_checking':
      case 'us_savings':
      case 'shariah_savings':
        final rates = params['tiered_interest_rates'] as Map<String, dynamic>?;
        if (rates != null && rates.isNotEmpty) {
          final firstTier = rates.values.first;
          if (firstTier is List && firstTier.isNotEmpty) {
            final rate = (firstTier.first as Map<String, dynamic>?)?['rate'];
            if (rate != null) {
              final pct = (rate as num).toDouble() * 100;
              info.add(('Interest Rate', '${pct.toStringAsFixed(2)}%'));
            }
          }
        }
        final minDeposit = params['minimum_deposit'];
        if (minDeposit != null) info.add(('Minimum Deposit', '\$$minDeposit'));
        final withdrawalLimits = params['tiered_daily_withdrawal_limits'] as Map<String, dynamic>?;
        if (withdrawalLimits != null && withdrawalLimits.isNotEmpty) {
          info.add(('Daily Withdrawal Limit', '\$${withdrawalLimits.values.first}'));
        }
        final minBalFee = params['minimum_balance_fee'];
        if (minBalFee != null) info.add(('Minimum Balance Fee', '\$$minBalFee'));
        final inactivityFee = params['inactivity_fee'];
        if (inactivityFee != null) info.add(('Inactivity Fee', '\$$inactivityFee'));

      case 'credit_card':
        final creditLimit = params['credit_limit'];
        if (creditLimit != null) info.add(('Credit Limit', '\$$creditLimit'));
        final apr = params['annual_percentage_rate'];
        if (apr is Map<String, dynamic> && apr.isNotEmpty) {
          final rate = apr.values.first;
          if (rate != null) {
            final pct = (rate as num).toDouble() * 100;
            info.add(('APR', '${pct.toStringAsFixed(2)}%'));
          }
        }
        final lateFee = params['late_repayment_fee'];
        if (lateFee != null) info.add(('Late Payment Fee', '\$$lateFee'));
        final annualFee = params['annual_fee'];
        if (annualFee != null) info.add(('Annual Fee', '\$$annualFee'));
        final minDue = params['minimum_amount_due'];
        if (minDue != null) info.add(('Minimum Due', '\$$minDue'));

      case 'loan':
      case 'mortgage':
      case 'home_loan_redraw':
      case 'line_of_credit':
        final rate = params['variable_interest_rate'];
        if (rate != null) {
          final pct = (rate as num).toDouble() * 100;
          info.add(('Interest Rate', '${pct.toStringAsFixed(2)}%'));
        }
        final penaltyRate = params['penalty_interest_rate'];
        if (penaltyRate != null) {
          final pct = (penaltyRate as num).toDouble() * 100;
          info.add(('Penalty Rate', '${pct.toStringAsFixed(2)}%'));
        }
        final lateFee = params['late_repayment_fee'];
        if (lateFee != null) info.add(('Late Fee', '\$$lateFee'));

      case 'time_deposit':
        final termUnit = params['term_unit'];
        if (termUnit != null) info.add(('Term Unit', termUnit.toString()));
        final depositPeriod = params['deposit_period'];
        if (depositPeriod != null) info.add(('Deposit Period', '$depositPeriod'));
    }

    return info;
  }
}
