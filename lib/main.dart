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
import 'platform/platform.dart';
import 'theme.dart';
import 'app_context.dart';
import 'bootstrap.dart';
import 'pages/pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics for e2e/Playwright ARIA access (per memory notes)
  SemanticsBinding.instance.ensureSemantics();
  // Native: prime the enrolled instance origin from disk before any network
  // call. No-op on web, where the origin comes from the address bar.
  await loadAppOrigin();
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

  /// True when the app has no enrolled instance origin yet.
  ///
  /// Web never sets this (the address bar is the origin); on native it is the
  /// first-run state and the user is shown the pairing screen.
  bool _bootstrapNeedsEnrollment = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Use the app's own origin so the TLS proxy injects the correct
      // X-Sentin8-Hostname header for runtime context resolution.
      //
      // Web: the address bar. Native: the origin persisted at enrollment; a
      // null value is not an error, it is the un-enrolled first-run state
      // (WS9 shows the pairing screen).
      final origin = appOrigin;
      if (origin == null || origin.isEmpty) {
        if (!mounted) return;
        setState(() {
          _bootstrapNeedsEnrollment = true;
        });
        return;
      }
      final ctx = await fetchRuntimeContext(
        appBaseUrl: origin,
        hostname: Uri.parse(origin).host,
      );

      // The bootstrap is async: the widget can be disposed while the context
      // fetch is in flight (test teardown, a fast back-navigation). setState on
      // a disposed State is a real error, not a warning.
      if (!mounted) return;
      setState(() {
        _runtimeContext = ctx;
      });
    } catch (e) {
      if (!mounted) return;
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

    if (_bootstrapNeedsEnrollment) {
      return EnrollmentPage(
        onEnrolled: () {
          setState(() {
            _bootstrapNeedsEnrollment = false;
          });
          _bootstrap();
        },
      );
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

    // /admin, /admin/products, /admin/open-banking
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

