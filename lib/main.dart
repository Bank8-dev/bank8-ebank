// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank main entry point
// Flutter app scaffold + Sentin8Provider initialization
//
// Bootstrap flow:
// 1. App starts, calls GET /v1/app/runtime/context (routed through TLS)
// 2. TLS injects X-Sentin8-App-Id, X-Sentin8-Env-Id headers
// 3. Receives AppRuntimeContext { authDomain, bffDomain, org, env }
// 4. Initializes AuthProvider with BFF base URL
// 5. Checks BFF /auth/session for existing session
// 6. Renders signed-in dashboard or landing page

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:web/web.dart' as web;
import 'theme.dart';
import 'app_context.dart';
import 'bootstrap.dart';
import 'pages/pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics for e2e/Playwright ARIA access (per memory notes)
  SemanticsBinding.instance.ensureSemantics();
  runApp(const EBankApp());
}

/// eBank root widget.
///
/// Shows a bootstrap loader while fetching runtime context, then the main app.
class EBankApp extends StatefulWidget {
  const EBankApp({super.key});

  @override
  State<EBankApp> createState() => _EBankAppState();
}

class _EBankAppState extends State<EBankApp> {
  AppRuntimeContext? _runtimeContext;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Use the app's own origin so the TLS proxy injects the correct
      // X-Sentin8-Hostname header for runtime context resolution.
      final appBaseUrl = web.window.location.origin;
      final ctx = await fetchRuntimeContext(appBaseUrl: appBaseUrl);

      setState(() {
        _runtimeContext = ctx;
      });
    } catch (e) {
      setState(() {
        _bootstrapError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _runtimeContext?.themeMode == 'dark';
    return MaterialApp(
      title: _runtimeContext?.displayName ?? 'eBank',
      theme: isDark
          ? sentin8DarkThemeForContext(_runtimeContext!)
          : (_runtimeContext != null
              ? sentin8ThemeForContext(_runtimeContext!)
              : sentin8Theme()),
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
      onGenerateRoute: _generateRoute,
    );
  }

  Widget _buildHome() {
    if (_bootstrapError != null) {
      return BootstrapErrorPage(error: _bootstrapError!, appName: 'eBank');
    }

    if (_runtimeContext == null) {
      return const BootstrapLoaderPage(appName: 'eBank');
    }

    return EBankContextProvider(
      runtimeContext: _runtimeContext!,
      child: const EBankShell(),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    // Hash-based routing for web compatibility
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;

    // /admin, /admin/products, /admin/fdx
    if (segments.isNotEmpty && segments.first == 'admin') {
      return MaterialPageRoute(
        builder: (_) => EBankContextProvider(
          runtimeContext: _runtimeContext!,
          child: const EBankShell(),
        ),
        settings: settings,
      );
    }
    return null;
  }
}

