// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank FDX consent dashboard - customer view of who has access to their data.
// FDX consent dashboard - view and revoke data-sharing consents.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';
import '../fdx_hooks.dart';

class FdxConsentDashboardPage extends StatefulWidget {
  final EBankContext appContext;

  const FdxConsentDashboardPage({super.key, required this.appContext});

  @override
  State<FdxConsentDashboardPage> createState() => _FdxConsentDashboardPageState();
}

class _FdxConsentDashboardPageState extends State<FdxConsentDashboardPage> {
  late FdxConsentsHook _consentsHook;

  @override
  void initState() {
    super.initState();
    _consentsHook = FdxConsentsHook(widget.appContext.services!.fdx);
    _consentsHook.fetch();
  }

  Future<void> _revokeConsent(String consentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Consent'),
        content: const Text(
          'This will immediately revoke data access for this recipient. '
          'They will no longer be able to access your account data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Sentin8Colors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _consentsHook.revoke(consentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Consent revoked successfully' : 'Failed to revoke consent'),
          backgroundColor: success ? Sentin8Colors.success : Sentin8Colors.error,
        ),
      );
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
            const Text('Data Sharing Consents', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.sm),
            const Text(
              'Manage who has access to your financial data. '
              'You can revoke access at any time.',
              style: Sentin8Text.bodyMedium,
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            ListenableBuilder(
              listenable: _consentsHook,
              builder: (_, __) {
                if (_consentsHook.state.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Sentin8Colors.primary));
                }

                if (_consentsHook.state.error != null) {
                  return GlassPanel(
                    child: Text('Error: ${_consentsHook.state.error}', style: const TextStyle(color: Sentin8Colors.error)),
                  );
                }

                final consents = _consentsHook.consents;
                if (consents.isEmpty) {
                  return const GlassPanel(
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: Sentin8Colors.textSecondary),
                          SizedBox(height: Sentin8Spacing.md),
                          Text('No active data sharing', style: Sentin8Text.headlineMedium),
                          SizedBox(height: Sentin8Spacing.xs),
                          Text('You have not shared data with any recipients.', style: Sentin8Text.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: consents.length,
                    itemBuilder: (context, index) {
                      final consent = consents[index];
                      return _buildConsentCard(consent);
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

  Widget _buildConsentCard(Map<String, dynamic> consent) {
    final recipientName = consent['recipientName'] as String? ?? 'Unknown Recipient';
    final recipientId = consent['recipientId'] as String? ?? '';
    final scopes = (consent['scopes'] as List<dynamic>?)?.cast<String>() ?? [];
    final status = consent['status'] as String? ?? 'ACTIVE';
    final createdAt = consent['createdAt'] as String? ?? '';
    final expiresAt = consent['expiresAt'] as String?;
    final consentId = consent['consentId'] as String? ?? consent['id'] as String? ?? '';
    final isActive = status == 'ACTIVE';

    return Padding(
      padding: const EdgeInsets.only(bottom: Sentin8Spacing.sm),
      child: GlassPanel(
        padding: const EdgeInsets.all(Sentin8Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share, color: Sentin8Colors.primary),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipientName, style: Sentin8Text.bodyLarge),
                      if (recipientId.isNotEmpty)
                        Text('ID: $recipientId', style: Sentin8Text.labelSmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sentin8Spacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Sentin8Colors.success.withValues(alpha: 0.1) : Sentin8Colors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Sentin8Colors.success : Sentin8Colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (scopes.isNotEmpty) ...[
              const SizedBox(height: Sentin8Spacing.sm),
              Wrap(
                spacing: 4,
                children: scopes.map((scope) => Chip(
                  label: Text(scope, style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            const SizedBox(height: Sentin8Spacing.xs),
            Text('Created: $createdAt', style: Sentin8Text.labelSmall),
            if (expiresAt != null)
              Text('Expires: $expiresAt', style: Sentin8Text.labelSmall),
            if (isActive) ...[
              const SizedBox(height: Sentin8Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _revokeConsent(consentId),
                  style: OutlinedButton.styleFrom(foregroundColor: Sentin8Colors.error),
                  child: const Text('Revoke Access'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _consentsHook.dispose();
    super.dispose();
  }
}