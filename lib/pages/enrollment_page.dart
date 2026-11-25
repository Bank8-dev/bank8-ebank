// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// First-run enrollment screen (native only).
//
// A browser learns which bank instance it belongs to from the address bar. A
// native app has no address bar, so the instance origin has to be established
// once and remembered - that is what this screen does.
//
// Scope note: this is the MINIMAL implementation needed to run the app on a
// device (validation layers L1-L7, the QR/App-Link path and the assurance-tier
// model are WS9 / `docs/06-runtime-enrollment.md`). The input here only
// accepts an https origin and refuses everything else.

import 'package:flutter/material.dart';

import '../platform/platform.dart';
import '../theme.dart';

/// Prompts for the bank instance origin and persists it.
class EnrollmentPage extends StatefulWidget {
  final VoidCallback onEnrolled;

  const EnrollmentPage({super.key, required this.onEnrolled});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter your bank\'s address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await saveAppOrigin(raw);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'That is not a valid https address.';
      });
      return;
    }
    setState(() => _busy = false);
    widget.onEnrolled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sentin8Spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_balance,
                      size: 56, color: Sentin8Colors.primary),
                  const SizedBox(height: Sentin8Spacing.lg),
                  Text('Connect to your bank',
                      style: Sentin8Text.headlineLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: Sentin8Spacing.sm),
                  Text(
                    'Enter the address your bank gave you. You only need to do '
                    'this once.',
                    style: Sentin8Text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Sentin8Spacing.xl),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.url],
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Bank address',
                      hintText: 'https://bank8-ebank-mobile.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Sentin8Spacing.sm),
                    Text(
                      _error!,
                      style: TextStyle(color: Sentin8Colors.error),
                    ),
                  ],
                  const SizedBox(height: Sentin8Spacing.lg),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: Sentin8Spacing.lg),
                  Text(
                    'If your bank gave you a QR code or an app link, use that '
                    'instead - it verifies the address for you.',
                    style: Sentin8Text.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
