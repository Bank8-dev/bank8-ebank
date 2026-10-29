// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank statements page - statement list and download via Storage signed URLs.
// Statements - list and download via BFF → Storage signed URLs.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_context.dart';

class StatementsPage extends StatefulWidget {
  final EBankContext appContext;
  final String? accountId;

  const StatementsPage({
    super.key,
    required this.appContext,
    this.accountId,
  });

  @override
  State<StatementsPage> createState() => _StatementsPageState();
}

class _StatementsPageState extends State<StatementsPage> {
  List<dynamic> _statements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatements();
  }

  Future<void> _loadStatements() async {
    setState(() => _loading = true);
    try {
      final path = widget.accountId != null
          ? '/v1/accounts/${widget.accountId}/statements'
          : '/v1/accounts/statements';
      final response = await widget.appContext.services!.ledger.get(path);
      if (response.isSuccess && response.data != null) {
        setState(() {
          _statements = response.data!['data'] as List<dynamic>? ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _statements = [];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _statements = [];
        _loading = false;
      });
    }
  }

  Future<void> _downloadStatement(Map<String, dynamic> statement) async {
    final objectPath = statement['objectPath'] as String?;
    if (objectPath == null) return;

    try {
      // Download through a Storage signed URL via the BFF proxy.
      final response = await widget.appContext.services!.storage.post(
        '/v1/storage/sign-read',
        body: {'objectPath': objectPath},
      );

      if (response.isSuccess && response.data != null) {
        final signedUrl = response.data!['signedUrl'] as String?;
        if (signedUrl != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statement download initiated: $signedUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
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
            const Text('Statements', style: Sentin8Text.headlineLarge),
            const SizedBox(height: Sentin8Spacing.lg),
            if (_statements.isEmpty)
              const GlassPanel(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined, size: 48, color: Sentin8Colors.textSecondary),
                      SizedBox(height: Sentin8Spacing.md),
                      Text('No statements available', style: Sentin8Text.headlineMedium),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _statements.length,
                  itemBuilder: (context, index) {
                    final statement = _statements[index] as Map<String, dynamic>;
                    final period = statement['period'] as String? ?? 'Statement';
                    final date = statement['date'] as String? ?? '';
                    final size = statement['sizeBytes'] as int?;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: Sentin8Spacing.xs),
                      child: ListTile(
                        leading: const Icon(Icons.description, color: Sentin8Colors.primary),
                        title: Text(period, style: Sentin8Text.bodyMedium),
                        subtitle: Text(
                          date + (size != null ? ' · ${_formatSize(size)}' : ''),
                          style: Sentin8Text.labelSmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download, color: Sentin8Colors.primary),
                          onPressed: () => _downloadStatement(statement),
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
}