// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

/// Transfer page - internal transfer between owned accounts.
/// Transfer page - internal transfers through Ledger postings.
///
/// Uses Payments transfer API via BFF proxy route.
/// Idempotency keys are mandatory for all money movement.
class TransferPage extends StatefulWidget {
  final EBankContext appContext;

  const TransferPage({super.key, required this.appContext});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  List<dynamic> _accounts = [];
  String? _fromAccount;
  String? _toAccount;
  final _amountController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final response = await widget.appContext.services!.ledger.get('/v1/accounts');
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

  Future<void> _submitTransfer() async {
    if (_fromAccount == null || _toAccount == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Internal account-to-account transfer - a simple double-entry
      // posting via Ledger. Payments instructions are for external payments
      // (SEPA, SWIFT, card) that need routing and orchestration; internal
      // transfers go directly to the ledger.
      final idempotencyKey = 'tf-${DateTime.now().millisecondsSinceEpoch}';
      final amountMajor = double.tryParse(_amountController.text) ?? 0;
      final amountMinor = (amountMajor * 100).round().toString();

      final response = await widget.appContext.services!.ledger.post(
        '/v1/postings',
        body: {
          'batch_id': 'ebank-transfer-${DateTime.now().millisecondsSinceEpoch}',
          'idempotency_key': idempotencyKey,
          'dry_run': false,
          'instructions': [
            {
              'instruction_type': 'transfer',
              'debit_account': _fromAccount,
              'credit_account': _toAccount,
              'amount': amountMinor,
              'denomination': 'CAD',
              'description': 'Transfer via eBank',
            }
          ],
        },
      );

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transfer submitted successfully')),
          );
          _amountController.clear();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transfer failed: ${response.error ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Build a human-readable label for an account dropdown item.
  /// Falls back through nickname → name → pretty-productType so the
  /// user sees a meaningful name even when Ledger doesn't return one
  /// (e.g. for accounts opened via the eBank product flow).
  Widget _accountLabel(Map<String, dynamic> a) {
    final productType = a['productType'] as String? ??
        a['accountType'] as String? ??
        '';
    final name = a['nickname'] as String? ??
        a['name'] as String? ??
        _prettyProductType(productType);
    final denom = a['denomination'] as String? ?? 'CAD';
    return Row(
      children: [
        Icon(productIconForType(productType),
            size: 18, color: Sentin8Colors.primary),
        const SizedBox(width: Sentin8Spacing.sm),
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        Text('· $denom', style: Sentin8Text.labelSmall),
      ],
    );
  }

  /// Pretty-print a product type into a human-readable account name.
  /// Mirrors the mapping in dashboard_page.dart / account_list_page.dart.
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
            const Text('Transfer', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From Account', style: Sentin8Text.labelSmall),
                  const SizedBox(height: Sentin8Spacing.xs),
                  DropdownButtonFormField<String>(
                    value: _fromAccount,
                    decoration: const InputDecoration(hintText: 'Select source account'),
                    items: _accounts.map((account) {
                      final a = account as Map<String, dynamic>;
                      final id = a['id'] as String? ?? '';
                      return DropdownMenuItem(value: id, child: _accountLabel(a));
                    }).toList(),
                    onChanged: (v) => setState(() => _fromAccount = v),
                  ),
                  const SizedBox(height: Sentin8Spacing.md),
                  const Text('To Account', style: Sentin8Text.labelSmall),
                  const SizedBox(height: Sentin8Spacing.xs),
                  DropdownButtonFormField<String>(
                    value: _toAccount,
                    decoration: const InputDecoration(hintText: 'Select destination account'),
                    items: _accounts.map((account) {
                      final a = account as Map<String, dynamic>;
                      final id = a['id'] as String? ?? '';
                      return DropdownMenuItem(value: id, child: _accountLabel(a));
                    }).toList(),
                    onChanged: (v) => setState(() => _toAccount = v),
                  ),
                  const SizedBox(height: Sentin8Spacing.md),
                  const Text('Amount', style: Sentin8Text.labelSmall),
                  const SizedBox(height: Sentin8Spacing.xs),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: Sentin8Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitTransfer,
                      child: _submitting
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Transfer'),
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
}