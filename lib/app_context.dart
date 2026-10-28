// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank app context — central runtime state
// Holds the AppRuntimeContext, AuthProvider, and EBankServices
// Provides them to the widget tree via InheritedWidget

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'bootstrap.dart';
import 'auth_provider.dart';
import 'services.dart';

/// Central app context that ties together runtime context, auth, and services.
///
/// Created after bootstrap completes. The AppRuntimeContext provides the
/// per-instance BFF domain and Auth domain. AuthProvider manages the BFF
/// session. EBankServices provides typed API clients for all backend services.
class EBankContext extends ChangeNotifier {
  final AppRuntimeContext runtimeContext;
  final AuthProvider auth;
  EBankServices? services;
  final String correlationId;

  EBankContext._({
    required this.runtimeContext,
    required this.auth,
    required this.correlationId,
  }) {
    // Wire up services once auth is loaded
    auth.addListener(_onAuthChanged);
    _updateServices();
  }

  /// Create the app context after bootstrap.
  static Future<EBankContext> create(AppRuntimeContext runtimeContext) async {
    final corrId = generateCorrelationId();
    final auth = AuthProvider(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      authDomain: runtimeContext.authDomain,
    );
    // Wire up redirect callback for web (window.location.href).
    auth.onRedirect = (String url) {
      web.window.location.href = url;
    };
    await auth.init();
    return EBankContext._(
      runtimeContext: runtimeContext,
      auth: auth,
      correlationId: corrId,
    );
  }

  void _onAuthChanged() {
    _updateServices();
    notifyListeners();
  }

  /// Ensure a Ledger customer row exists for the signed-in user.
  /// Called by the app before account opening (e.g. product_detail_page).
  /// Idempotent: Ledger returns 409 if the customer already exists, which
  /// we treat as success. Only eBank calls this — eOpenCA doesn't use Ledger.
  Future<void> ensureLedgerCustomer() async {
    final user = auth.user;
    final s = services;
    if (user == null || s == null) return;
    try {
      final resp = await s.ledger.post('/v1/customers', body: {
        'display_name': user.displayName ?? user.email,
        'email': user.email,
      });
      if (resp.statusCode == 201 || resp.statusCode == 409) {
        // Created or already exists — fine.
      } else {
        print('[eBank] ensureLedgerCustomer: unexpected status ${resp.statusCode}');
      }
    } catch (e) {
      print('[eBank] ensureLedgerCustomer error: $e');
    }
  }

  void _updateServices() {
    services = EBankServices(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      csrfToken: auth.csrfToken,
      correlationId: correlationId,
    );
  }

  /// Feature gate check against the runtime context's enabled features.
  bool isFeatureEnabled(String feature) {
    return runtimeContext.featureFlags[feature] ?? true;
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    auth.dispose();
    super.dispose();
  }
}

/// StatefulWidget providing EBankContext to the widget tree.
/// Initializes EBankContext asynchronously from the runtime context.
class EBankContextProvider extends StatefulWidget {
  final AppRuntimeContext runtimeContext;
  final Widget child;

  const EBankContextProvider({
    super.key,
    required this.runtimeContext,
    required this.child,
  });

  @override
  State<EBankContextProvider> createState() => _EBankContextProviderState();

  static EBankContext? of(BuildContext context) {
    final inh = context.dependOnInheritedWidgetOfExactType<_EBankContextInherited>();
    return inh?.eBankContext;
  }
}

class _EBankContextProviderState extends State<EBankContextProvider> {
  EBankContext? _context;

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  Future<void> _initContext() async {
    final ctx = await EBankContext.create(widget.runtimeContext);
    if (mounted) {
      setState(() {
        _context = ctx;
      });
    }
  }

  @override
  void dispose() {
    _context?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_context == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _EBankContextInherited(
      eBankContext: _context!,
      child: widget.child,
    );
  }
}

class _EBankContextInherited extends InheritedWidget {
  final EBankContext eBankContext;

  const _EBankContextInherited({required this.eBankContext, required super.child});

  @override
  bool updateShouldNotify(_EBankContextInherited old) =>
      eBankContext != old.eBankContext;
}