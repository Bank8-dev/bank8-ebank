// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank account detail page - full account details with balances and transactions.
// Account detail - balances and transaction timeline.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';
import '../hooks.dart';

class AccountDetailPage extends StatefulWidget {
  final EBankContext appContext;
  final String accountId;
  final VoidCallback? onBack;

  const AccountDetailPage({
    super.key,
    required this.appContext,
    required this.accountId,
    this.onBack,
  });

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  Map<String, dynamic>? _account;
  final _balancesHook = ValueNotifier<BalancesHook?>(null);
  final _transactionsHook = ValueNotifier<TransactionsHook?>(null);
  bool _loadingAccount = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load account detail
    try {
      final response = await widget.appContext.services!.ledger.get('/v1/accounts/${widget.accountId}');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _account = response.data!['account'] as Map<String, dynamic>? ?? response.data;
          _loadingAccount = false;
        });
      } else {
        setState(() => _loadingAccount = false);
      }
    } catch (_) {
      setState(() => _loadingAccount = false);
    }

    // Initialize hooks
    final ledger = widget.appContext.services!.ledger;
    final balHook = BalancesHook(ledger, widget.accountId);
    final txnHook = TransactionsHook(ledger, widget.accountId);

    balHook.fetch();
    txnHook.fetch();

    _balancesHook.value = balHook;
    _transactionsHook.value = txnHook;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Sentin8Colors.primary)),
      );
    }

    final account = _account ?? {};

    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: Padding(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Sentin8Colors.primary),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
                Icon(
                  productIconForType(
                    account['product_type'] as String? ??
                        account['account_type'] as String?,
                  ),
                  color: Sentin8Colors.primary,
                  size: 28,
                ),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(
                  child: Text(
                    account['nickname'] as String? ?? account['name'] as String? ?? 'Account',
                    style: Sentin8Text.headlineLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildBalanceCard(),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildAccountInfo(),
            const SizedBox(height: Sentin8Spacing.lg),
            const Text('Transactions', style: Sentin8Text.headlineMedium),
            const SizedBox(height: Sentin8Spacing.md),
            Expanded(child: _buildTransactionsList()),
          ],
        ),
      ),
    );
  }

  /// Parse a balance amount string (PostgreSQL numeric) to a double
  /// in major units. Ledger stores amounts in minor units (cents).
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble() / 100;
    final str = value.toString();
    final parsed = double.tryParse(str) ?? 0.0;
    return parsed / 100;
  }

  Widget _buildBalanceCard() {
    final account = _account ?? {};
    return ValueListenableBuilder(
      valueListenable: _balancesHook,
      builder: (_, hook, __) {
        final data = hook?.state.data ?? {};
        // Balances API returns an array of balance objects wrapped as
        // {'data': [{'account_id':..., 'denomination':..., 'address':...,
        //   'phase':..., 'amount': '300.0000'}]}
        final balancesList = (data['data'] as List<dynamic>?) ?? [];
        // Find the first balance with address 'available' or 'current'.
        // Falls back to the first balance in the list.
        double current = 0;
        double available = 0;
        if (balancesList.isNotEmpty) {
          final availableBal = balancesList.firstWhere(
            (b) => (b as Map<String, dynamic>)['address'] == 'available',
            orElse: () => balancesList.first,
          ) as Map<String, dynamic>;
          final currentBal = balancesList.firstWhere(
            (b) => (b as Map<String, dynamic>)['address'] == 'current',
            orElse: () => availableBal,
          ) as Map<String, dynamic>;
          current = _parseAmount(currentBal['amount']);
          available = _parseAmount(availableBal['amount']);
        }

        return GlassPanel(
          child: Row(
            children: [
              Icon(
                productIconForType(
                  account['product_type'] as String? ??
                      account['account_type'] as String?,
                ),
                color: Sentin8Colors.primary,
                size: 40,
              ),
              const SizedBox(width: Sentin8Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Balance', style: Sentin8Text.labelSmall),
                    Text('\$${current.toStringAsFixed(2)}', style: Sentin8Text.headlineLarge),
                    Text('Available: \$${available.toStringAsFixed(2)}', style: Sentin8Text.labelSmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Sentin8Colors.textSecondary),
                onPressed: () => hook?.fetch(),
                tooltip: 'Refresh',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountInfo() {
    final account = _account ?? {};
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Details', style: Sentin8Text.headlineMedium),
          const SizedBox(height: Sentin8Spacing.md),
          _infoRow('Type', account['account_type'] as String? ?? account['product_type'] as String? ?? ' - '),
          _infoRow('Status', account['status'] as String? ?? ' - '),
          _infoRow('Nickname', account['nickname'] as String? ?? ' - '),
          _infoRow('Currency', account['denomination'] as String? ?? ' - '),
          _infoRow('Opened', account['opened_at'] as String? ?? ' - '),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: Sentin8Text.labelSmall)),
          Expanded(child: Text(value, style: Sentin8Text.bodyMedium)),
        ],
      ),
    );
  }

  String _maskNumber(String number) {
    if (number.length <= 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  Widget _buildTransactionsList() {
    return ValueListenableBuilder(
      valueListenable: _transactionsHook,
      builder: (_, hook, __) {
        if (hook == null || hook.state.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Sentin8Colors.primary));
        }

        final transactions = hook.transactions;
        if (transactions.isEmpty) {
          return const GlassPanel(
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Sentin8Colors.textSecondary),
                  SizedBox(height: Sentin8Spacing.md),
                  Text('No transactions yet', style: Sentin8Text.headlineMedium),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            return _buildTransactionTile(txn);
          },
        );
      },
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn) {
    final desc = txn['description'] as String? ?? 'Transaction';
    // TransactionResponse.amount is a String (PostgreSQL numeric), in minor units.
    final amountVal = _parseAmount(txn['amount']);
    // TransactionResponse.direction is 'DEBIT' or 'CREDIT'.
    final direction = txn['direction'] as String? ?? 'DEBIT';
    final isDebit = direction == 'DEBIT';
    // TransactionResponse.value_timestamp is an ISO-8601 string.
    final date = txn['value_timestamp'] as String? ?? txn['booking_timestamp'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
      child: ListTile(
        leading: Icon(
          isDebit ? Icons.arrow_outward : Icons.arrow_downward,
          color: isDebit ? Sentin8Colors.error : Sentin8Colors.success,
        ),
        title: Text(desc, style: Sentin8Text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(date, style: Sentin8Text.labelSmall),
        trailing: Text(
          '${isDebit ? '-' : '+'}\$${amountVal.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDebit ? Sentin8Colors.error : Sentin8Colors.success,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _balancesHook.value?.dispose();
    _transactionsHook.value?.dispose();
    _balancesHook.dispose();
    _transactionsHook.dispose();
    super.dispose();
  }
}