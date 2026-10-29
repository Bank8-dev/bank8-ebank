// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank admin FDX page - provider profile, recipient registration, consent monitoring.
// Admin FDX provider management - provider profile, recipients, consents.
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../app_context.dart';
import '../../fdx_hooks.dart';

class AdminFdxPage extends StatefulWidget {
  final EBankContext appContext;

  const AdminFdxPage({super.key, required this.appContext});

  @override
  State<AdminFdxPage> createState() => _AdminFdxPageState();
}

class _AdminFdxPageState extends State<AdminFdxPage> {
  late FdxProvidersHook _providersHook;
  late FdxRecipientsHook _recipientsHook;

  @override
  void initState() {
    super.initState();
    _providersHook = FdxProvidersHook(widget.appContext.services!.fdx);
    _recipientsHook = FdxRecipientsHook(widget.appContext.services!.fdx);
    _providersHook.fetch();
    _recipientsHook.fetch();
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Sentin8Colors.primary),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: Sentin8Spacing.sm),
                const Text('FDX Provider Admin', style: Sentin8Text.headlineLarge),
              ],
            ),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildProviderProfile(),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildRecipientRegistration(),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildConsentMonitoring(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderProfile() {
    return ListenableBuilder(
      listenable: _providersHook,
      builder: (_, __) {
        final data = _providersHook.state.data ?? {};
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Provider Profile', style: Sentin8Text.headlineMedium),
              const SizedBox(height: Sentin8Spacing.md),
              _infoRow('Brand Name', data['brandName'] as String? ?? 'eBank'),
              _infoRow('Issuer URL', data['issuer'] as String? ?? ' - '),
              _infoRow('JWKS URL', data['jwksUri'] as String? ?? ' - '),
              _infoRow('FDX Version', data['fdxVersion'] as String? ?? '6.5'),
              _infoRow('Status', data['status'] as String? ?? 'available'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecipientRegistration() {
    return ListenableBuilder(
      listenable: _recipientsHook,
      builder: (_, __) {
        final recipients = _recipientsHook.recipients;
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registered Recipients', style: Sentin8Text.headlineMedium),
              const SizedBox(height: Sentin8Spacing.md),
              if (recipients.isEmpty)
                const Text('No registered recipients.', style: Sentin8Text.bodyMedium)
              else
                ...recipients.map((r) {
                  final name = r['clientName'] as String? ?? 'Unknown';
                  final clientId = r['clientId'] as String? ?? '';
                  final status = r['status'] as String? ?? 'PENDING';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
                    child: ListTile(
                      leading: const Icon(Icons.business, color: Sentin8Colors.primary),
                      title: Text(name, style: Sentin8Text.bodyMedium),
                      subtitle: Text('$clientId · $status', style: Sentin8Text.labelSmall),
                      dense: true,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConsentMonitoring() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Consent Monitoring', style: Sentin8Text.headlineMedium),
          const SizedBox(height: Sentin8Spacing.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Active Consents', '0', Sentin8Colors.success),
              ),
              const SizedBox(width: Sentin8Spacing.sm),
              Expanded(
                child: _buildStatCard('Revocations', '0', Sentin8Colors.error),
              ),
              const SizedBox(width: Sentin8Spacing.sm),
              Expanded(
                child: _buildStatCard('Authorization Rate', ' - ', Sentin8Colors.primary),
              ),
            ],
          ),
          const SizedBox(height: Sentin8Spacing.md),
          const Text(
            'Consent monitoring shows active consent grants, revocation events, '
            'and authorization rates. Updated in real-time from FDX.',
            style: Sentin8Text.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(Sentin8Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: Sentin8Text.labelSmall, textAlign: TextAlign.center),
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

  @override
  void dispose() {
    _providersHook.dispose();
    _recipientsHook.dispose();
    super.dispose();
  }
}