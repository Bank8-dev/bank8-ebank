// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank admin product management page - browse 13 Ledger products, activate/deactivate, override params.
// Admin product management via the Ledger admin API.
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../app_context.dart';

class AdminProductsPage extends StatefulWidget {
  final EBankContext appContext;

  const AdminProductsPage({super.key, required this.appContext});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  List<dynamic> _products = [];
  Set<String> _activeProducts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final response = await widget.appContext.services!.ledger.get('/v1/products');
      if (response.isSuccess && response.data != null) {
        final products = response.data!['data'] as List<dynamic>? ?? [];
        setState(() {
          _products = products;
          _loading = false;
        });
      } else {
        setState(() {
          _products = [];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _products = [];
        _loading = false;
      });
    }
  }

  Future<void> _toggleProduct(String productId, bool activate) async {
    try {
      // Parameter overrides ride BFF → Ledger POST /products/:id/versions.
      await widget.appContext.services!.ledger.post(
        '/v1/products/$productId/versions',
        body: {'active': activate},
      );
      setState(() {
        if (activate) {
          _activeProducts.add(productId);
        } else {
          _activeProducts.remove(productId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Sentin8Colors.primary),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: Sentin8Spacing.sm),
                const Text('Product Management', style: Sentin8Text.headlineLarge),
              ],
            ),
            const SizedBox(height: Sentin8Spacing.sm),
            const Text(
              'Browse all 13 Ledger product library manifests. '
              'Activate, deactivate, or override parameters per environment.',
              style: Sentin8Text.bodyMedium,
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            Expanded(
              child: _products.isEmpty
                  ? const GlassPanel(
                      child: Center(
                        child: Text('No products available.', style: Sentin8Text.bodyLarge),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index] as Map<String, dynamic>;
                        final id = product['id'] as String? ?? '';
                        final name = product['name'] as String? ?? 'Product';
                        final type = product['productType'] as String? ?? '';
                        final isActive = _activeProducts.contains(id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: Sentin8Spacing.sm),
                          child: GlassPanel(
                            padding: const EdgeInsets.all(Sentin8Spacing.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: Sentin8Text.bodyLarge),
                                      if (type.isNotEmpty) Text(type, style: Sentin8Text.labelSmall),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  onChanged: (value) => _toggleProduct(id, value),
                                  activeColor: Sentin8Colors.success,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}