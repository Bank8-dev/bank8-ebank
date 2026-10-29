// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank product catalog page - browse all Ledger products with key info.
// Shows interest rates, fees, limits, and denomination on each card.
// Each card has an "Open Account" button that navigates to the detail page.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../url_router.dart';
import '../app_context.dart';
import 'product_detail_page.dart';

/// Product catalog page - browse all Ledger products.
/// Shows key product info (interest rate, fees, limits, denomination) on cards.
/// Each card has an "Open Account" button.
class ProductCatalogPage extends StatefulWidget {
  final EBankContext appContext;

  const ProductCatalogPage({super.key, required this.appContext});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  List<dynamic> _products = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      print('[eBank] Products: loading from /v1/products');
      final response =
          await widget.appContext.services!.ledger.get('/v1/products');
      print('[eBank] Products: response status=${response.statusCode} isSuccess=${response.isSuccess}');
      if (response.isSuccess && response.data != null) {
        final products = response.data!['data'] as List<dynamic>? ?? [];
        print('[eBank] Products: got ${products.length} products');
        setState(() {
          _products = products;
          _loading = false;
        });
      } else {
        print('[eBank] Products: response not success, data=${response.data}');
        setState(() {
          _products = [];
          _loading = false;
        });
      }
    } catch (e) {
      print('[eBank] Products: error loading: $e');
      setState(() {
        _products = [];
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

    // If a product is selected, show the detail form inline (keeping
    // the sidebar visible). The back button pops the selection.
    if (_selectedProduct != null) {
      return ProductDetailPage(
        appContext: widget.appContext,
        product: _selectedProduct!,
        onBack: () {
          setState(() => _selectedProduct = null);
          navigateTo('/products');
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
            const Text('Products', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.sm),
            const Text(
              'Browse and open from all available product types.',
              style: Sentin8Text.bodyMedium,
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            // The shell wraps the page in a SingleChildScrollView with a
            // minHeight constraint, so the vertical space is unbounded.
            // Use shrinkWrap + NeverScrollableScrollPhysics on the
            // ListView so it lays out inside the scroll view without
            // requiring an Expanded (which would assert with infinite
            // height).
            if (_products.isEmpty)
              const GlassPanel(
                child: Center(
                  child: Text('No products available.',
                      style: Sentin8Text.bodyLarge),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product =
                      _products[index] as Map<String, dynamic>;
                  return _buildProductCard(product);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ??
        product['productName'] as String? ??
        'Product';
    final type =
        product['productType'] as String? ?? product['type'] as String? ?? '';
    final params = (product['parameters'] as Map<String, dynamic>?) ?? {};
    final icon = _iconForType(type);
    final info = _keyInfoForProduct(type, params);

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.md),
      // Expose the product name as the card's semantics label so screen
      // readers (and the e2e harness clickFlutterButton) can locate the
      // product by name. Flutter web collapses plain Text-in-Row semantics,
      // so we wrap the card in an explicit Semantics node. The whole card
      // is tappable to open the product detail page.
      child: Semantics(
        label: name,
        button: true,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedProduct = product);
            final slug = product['slug'] ?? product['name'] ?? '';
            if (slug is String && slug.isNotEmpty) pushRoute('/products/$slug');
          },
          child: GlassPanel(
            padding: const EdgeInsets.all(Sentin8Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with icon + name + type badge
                Row(
                  children: [
                    Icon(icon, color: Sentin8Colors.primary, size: 28),
                    const SizedBox(width: Sentin8Spacing.sm),
                    Expanded(
                      child: Text(name,
                          style: Sentin8Text.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Sentin8Colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_prettyType(type),
                            style: const TextStyle(
                                color: Sentin8Colors.primary, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: Sentin8Spacing.sm),
                // Key info row
                Wrap(
                  spacing: Sentin8Spacing.sm,
                  runSpacing: Sentin8Spacing.xs,
                  children: info
                      .map((item) => _InfoChip(label: item.$1, value: item.$2))
                      .toList(),
                ),
                const SizedBox(height: Sentin8Spacing.md),
                // Open Account button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedProduct = product);
                      final slug = product['slug'] ?? product['name'] ?? '';
                      if (slug is String && slug.isNotEmpty) pushRoute('/products/$slug');
                    },
                    child: const Text('Open Account'),
                  ),
                ),
              ],
            ),
          ), // GlassPanel
        ), // GestureDetector
      ), // Semantics
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'current_account' || 'us_checking' => Icons.account_balance_wallet,
      'savings_account' || 'us_savings' || 'shariah_savings' => Icons.savings,
      'credit_card' => Icons.credit_card,
      'loan' ||
      'mortgage' ||
      'home_loan_redraw' ||
      'line_of_credit' =>
        Icons.home_work,
      'time_deposit' => Icons.lock_clock,
      'wallet' => Icons.wallet,
      'bnpl' => Icons.shopping_bag,
      _ => Icons.category,
    };
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

  /// Extract key product info that matters to consumers.
  List<(String, String)> _keyInfoForProduct(
      String type, Map<String, dynamic> params) {
    final info = <(String, String)>[];
    final denom = params['denomination'] as String? ?? 'CAD';
    info.add(('Currency', denom));

    switch (type) {
      case 'current_account':
      case 'savings_account':
      case 'us_checking':
      case 'us_savings':
      case 'shariah_savings':
        // Interest rate
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
        // Minimum deposit
        final minDeposit = params['minimum_deposit'];
        if (minDeposit != null) {
          info.add(('Min Deposit', '\$$minDeposit'));
        }
        // Daily withdrawal limit
        final withdrawalLimits =
            params['tiered_daily_withdrawal_limits'] as Map<String, dynamic>?;
        if (withdrawalLimits != null && withdrawalLimits.isNotEmpty) {
          final firstLimit = withdrawalLimits.values.first;
          info.add(('Daily Withdrawal Limit', '\$$firstLimit'));
        }
        // Minimum balance fee
        final minBalFee = params['minimum_balance_fee'];
        if (minBalFee != null) {
          info.add(('Min Balance Fee', '\$$minBalFee'));
        }

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
        if (lateFee != null) info.add(('Late Fee', '\$$lateFee'));
        final annualFee = params['annual_fee'];
        if (annualFee != null) info.add(('Annual Fee', '\$$annualFee'));

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

      case 'time_deposit':
        final termUnit = params['term_unit'];
        if (termUnit != null) info.add(('Term Unit', termUnit.toString()));
        final depositPeriod = params['deposit_period'];
        if (depositPeriod != null)
          info.add(('Deposit Period', '$depositPeriod'));
    }

    return info;
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Sentin8Colors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Sentin8Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Sentin8Colors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Sentin8Colors.textPrimary)),
        ],
      ),
    );
  }
}
