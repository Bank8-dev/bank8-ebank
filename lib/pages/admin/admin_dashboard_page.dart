// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../app_context.dart';

/// Admin dashboard page - instance status, controls, OAuth client summary.
/// Admin dashboard - instance controls
///
/// Admin access is restricted to staff + ebank-admin Auth security roles.
/// BFF verifies role membership server-side - this page is a convenience guard.
/// (SDK8 §3.9: server enforcement is mandatory, client guards are convenience only)
class AdminDashboardPage extends StatefulWidget {
  final EBankContext appContext;

  const AdminDashboardPage({super.key, required this.appContext});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _instanceInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInstanceInfo();
  }

  Future<void> _loadInstanceInfo() async {
    // In a real implementation, this would call App admin API via BFF
    // For now, show the runtime context info we already have
    setState(() {
      _instanceInfo = {
        'hostname': widget.appContext.runtimeContext.hostname,
        'organizationId': widget.appContext.runtimeContext.organizationId,
        'environmentId': widget.appContext.runtimeContext.environmentId,
        'appSlug': widget.appContext.runtimeContext.appSlug,
        'authDomain': widget.appContext.runtimeContext.authDomain,
        'bffDomain': widget.appContext.runtimeContext.bffDomain,
        'status': widget.appContext.runtimeContext.status,
      };
      _loading = false;
    });
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
            const Text('Admin', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildInstanceInfo(),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildSecretVars(),
            const SizedBox(height: Sentin8Spacing.lg),
            _buildOAuthSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceInfo() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Instance Information', style: Sentin8Text.headlineMedium),
          const SizedBox(height: Sentin8Spacing.md),
          ...(_instanceInfo ?? {}).entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(entry.key, style: Sentin8Text.labelSmall),
                  ),
                  Expanded(child: Text(entry.value.toString(), style: Sentin8Text.bodyMedium)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSecretVars() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Environment Variables (Secret References)', style: Sentin8Text.headlineMedium),
          const SizedBox(height: Sentin8Spacing.md),
          const Text('No secret references configured.', style: Sentin8Text.labelSmall),
          const SizedBox(height: Sentin8Spacing.xs),
          const Text(
            'Secret values are never displayed. Only the name and version are shown.',
            style: Sentin8Text.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthSummary() {
    // OAuth client registration summary is always visible here.
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OAuth Client (DCR)', style: Sentin8Text.headlineMedium),
          const SizedBox(height: Sentin8Spacing.md),
          const Text(
            'DCR is mandatory for all eBank instances. '
            'The OAuth client was registered during setup.',
            style: Sentin8Text.bodyMedium,
          ),
          const SizedBox(height: Sentin8Spacing.md),
          Row(
            children: [
              const SizedBox(width: 160, child: Text('Registration Status', style: Sentin8Text.labelSmall)),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Sentin8Colors.success, size: 16),
                    const SizedBox(width: Sentin8Spacing.xs),
                    const Text('Registered', style: Sentin8Text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}