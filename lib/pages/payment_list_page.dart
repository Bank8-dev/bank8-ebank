// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank payment list page — external payment history from Payments.
// Payment list — payments and payee history via the payments API.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';
import '../hooks.dart';

class PaymentListPage extends StatefulWidget {
  final EBankContext appContext;

  const PaymentListPage({super.key, required this.appContext});

  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  late PaymentsHook _paymentsHook;
  late PayeesHook _payeesHook;

  @override
  void initState() {
    super.initState();
    _paymentsHook = PaymentsHook(widget.appContext.services!.payments);
    _payeesHook = PayeesHook(widget.appContext.services!.payments);
    _paymentsHook.fetch();
    _payeesHook.fetch();
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
            const Text('Payments', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            ListenableBuilder(
              listenable: _paymentsHook,
              builder: (_, __) {
                if (_paymentsHook.state.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Sentin8Colors.primary));
                }

                if (_paymentsHook.paymentList.isEmpty) {
                  return const GlassPanel(
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.payments_outlined, size: 48, color: Sentin8Colors.textSecondary),
                          SizedBox(height: Sentin8Spacing.md),
                          Text('No payments yet', style: Sentin8Text.headlineMedium),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: _paymentsHook.paymentList.length,
                    itemBuilder: (context, index) {
                      final payment = _paymentsHook.paymentList[index];
                      return _buildPaymentTile(payment);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> payment) {
    final amount = payment['amount'] as num? ?? 0;
    final status = payment['status'] as String? ?? 'PENDING';
    final date = payment['createdAt'] as String? ?? payment['date'] as String? ?? '';
    final payee = payment['payeeName'] as String? ?? payment['counterparty'] as String? ?? 'Payment';

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
      child: GlassPanel(
        padding: const EdgeInsets.all(Sentin8Spacing.md),
        child: ListTile(
          leading: const Icon(Icons.payment, color: Sentin8Colors.primary),
          title: Text(payee, style: Sentin8Text.bodyMedium),
          subtitle: Text('$date · $status', style: Sentin8Text.labelSmall),
          trailing: Text('\$${amount.toDouble().toStringAsFixed(2)}', style: Sentin8Text.bodyLarge),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _paymentsHook.dispose();
    _payeesHook.dispose();
    super.dispose();
  }
}