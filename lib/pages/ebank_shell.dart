// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import '../theme.dart';
import '../app_context.dart';
import '../notification_sse.dart';
import '../url_router.dart';
import 'landing_page.dart';
import 'dashboard_page.dart';
import 'account_list_page.dart';
import 'account_detail_page.dart';
import 'product_catalog_page.dart';
import 'product_detail_page.dart';
import 'transfer_page.dart';
import 'payment_list_page.dart';
import 'lending_products_page.dart';
import 'savings_products_page.dart';
import 'statements_page.dart';
import 'messages_page.dart';
import 'fdx_consent_dashboard_page.dart';
import 'admin/admin_dashboard_page.dart';
import 'admin/admin_products_page.dart';
import 'admin/admin_fdx_page.dart';

/// Main app shell with navigation.
/// Shows landing page when signed out, dashboard when signed in.
///
/// Uses hash-based routing for web compatibility.
/// Sidebar navigation for: Dashboard, Accounts, Products, Transfers, Admin
class EBankShell extends StatefulWidget {
  const EBankShell({super.key});

  @override
  State<EBankShell> createState() => _EBankShellState();
}

class _EBankShellState extends State<EBankShell> {
  String _currentRoute = '/';
  NotificationSseClient? _sseClient;

  @override
  void initState() {
    super.initState();
    _currentRoute = currentRoute();
    if (kIsWeb) {
      web.window.onPopState.listen((_) {
        if (mounted) setState(() { _currentRoute = currentRoute(); });
      });
    }
  }

  void _navigate(String route) {
    setState(() {
      _currentRoute = route;
    });
    navigateTo(route);
  }

  void _ensureSseClient(EBankContext appContext) {
    if (_sseClient == null && appContext.auth.isSignedIn) {
      final bffBase = appContext.runtimeContext.bffBaseUrl;
      if (bffBase.isNotEmpty) {
        _sseClient = NotificationSseClient(
          bffBaseUrl: bffBase,
          fetchUnreadCount: () async {
            final services = appContext.services;
            if (services == null) return 0;
            final resp = await services.post.get('/v1/messages', queryParams: {'mine': 'true', 'unread': 'true', 'limit': '500'});
            if (!resp.isSuccess) return 0;
            final data = resp.data?['data'] as List<dynamic>? ?? [];
            return data.length;
          },
        );
        _sseClient!.connect();
        _sseClient!.addListener(_onSseChanged);
      }
    }
  }

  void _onSseChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appContext = EBankContextProvider.of(context);

    if (appContext == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cache context and listen to auth state changes (add listener only once)
    if (_cachedContext != appContext) {
      _cachedContext?.auth.removeListener(_onAuthChanged);
      _cachedContext = appContext;
      appContext.auth.addListener(_onAuthChanged);
    }

    if (!appContext.auth.isLoaded) {
      // Auth state is still being resolved (BFF /auth/session call in
      // flight). Show a loading indicator instead of the LandingPage so
      // the user doesn't briefly see "Sign In" / "Sign Up" buttons that
      // flicker away once the session is verified.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!appContext.auth.isSignedIn) {
      return LandingPage(appContext: appContext);
    }

    final isAdmin = _isAdmin(appContext);

    _ensureSseClient(appContext);

    Widget content;
    switch (_currentRoute) {
      case '/':
        content = DashboardPage(appContext: appContext, onNavigate: _navigate);
        break;
      case '/accounts':
        content = AccountListPage(appContext: appContext);
        break;
      case '/products':
        content = ProductCatalogPage(appContext: appContext);
        break;
      case '/transfers':
        content = TransferPage(appContext: appContext);
        break;
      case '/payments':
        content = PaymentListPage(appContext: appContext);
        break;
      case '/lending':
        content = LendingProductsPage(appContext: appContext);
        break;
      case '/savings':
        content = SavingsProductsPage(appContext: appContext);
        break;
      case '/statements':
        content = StatementsPage(appContext: appContext);
        break;
      case '/fdx/consents':
        content = FdxConsentDashboardPage(appContext: appContext);
        break;
      case '/messages':
        content = MessagesPage(appContext: appContext, sseClient: _sseClient);
        break;
      case '/admin':
        content = isAdmin
            ? AdminDashboardPage(appContext: appContext)
            : const _AccessDeniedPage();
        break;
      case '/admin/products':
        content = isAdmin
            ? AdminProductsPage(appContext: appContext)
            : const _AccessDeniedPage();
        break;
      case '/admin/fdx':
        content = isAdmin
            ? AdminFdxPage(appContext: appContext)
            : const _AccessDeniedPage();
        break;
      default:
        content = DashboardPage(appContext: appContext);
    }

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(appContext, isAdmin),
          VerticalDivider(width: 1, color: Sentin8Colors.border),
          // Each page returns its own Scaffold; the shell gives it the
          // available width and an unbounded vertical scroll so any
          // overflow can be scrolled. The pages themselves are free to
          // use their own ListView / Expanded inside the scroll view.
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(EBankContext appContext, bool isAdmin) {
    final appName = appContext.runtimeContext.displayName;
    final logoUrl = appContext.runtimeContext.logoIconUrl.isNotEmpty
        ? appContext.runtimeContext.logoIconUrl
        : appContext.runtimeContext.logoUrl;
    return Container(
      width: 240,
      color: Sentin8Colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Sentin8Spacing.lg),
            child: Row(
              children: [
                if (logoUrl.isNotEmpty)
                  networkLogo(
                    logoUrl,
                    size: 28,
                    fallbackWidget: const Icon(Icons.account_balance, color: Sentin8Colors.primary, size: 28),
                  )
                else
                  const Icon(Icons.account_balance, color: Sentin8Colors.primary, size: 28),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(
                  child: Text(appName, style: Sentin8Text.headlineMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const Divider(),
          // Notification bell with unread badge.
          if (_sseClient != null)
            _NotificationBell(
              unreadCount: _sseClient!.unreadCount,
              onTap: () => _navigate('/messages'),
            ),
          // Nav list scrolls if it overflows the viewport; the user
          // menu below stays pinned to the bottom.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: '/',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Accounts',
                    route: '/accounts',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.category_outlined,
                    label: 'Products',
                    route: '/products',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.swap_horiz,
                    label: 'Transfers',
                    route: '/transfers',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.payments_outlined,
                    label: 'Payments',
                    route: '/payments',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.request_quote_outlined,
                    label: 'Lending',
                    route: '/lending',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.savings_outlined,
                    label: 'Savings',
                    route: '/savings',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.description_outlined,
                    label: 'Statements',
                    route: '/statements',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.shield_outlined,
                    label: 'Data Sharing',
                    route: '/fdx/consents',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.mail_outline,
                    label: 'Messages',
                    route: '/messages',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  if (isAdmin) ...[
                    const Divider(),
                    _NavItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admin',
                      route: '/admin',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.category_outlined,
                      label: 'Admin: Products',
                      route: '/admin/products',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.shield_outlined,
                      label: 'Admin: FDX',
                      route: '/admin/fdx',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(),
          _UserMenu(appContext: appContext),
        ],
      ),
    );
  }

  bool _isAdmin(EBankContext appContext) {
    // eBank admin surfaces are guarded by the app-declared `ebank:admin`
    // role-marker scope. That scope is granted exclusively to members of
    // the `ebank-admin` role, which App provisions in `auth_roles`
    // when the listing is installed in a target org/env.
    //
    // We use an exact match against `ebank:admin` — a substring match
    // would false-positive on ebank customer accounts that hold
    // `fdx:admin` / `fdx:provider:write:admin` etc.
    //
    // Per SDK8 §3.9, server enforcement is mandatory — this client
    // guard only hides UI affordances.
    return appContext.auth.state.scopes.contains('ebank:admin');
  }

  EBankContext? _cachedContext;

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cachedContext?.auth.removeListener(_onAuthChanged);
    _sseClient?.removeListener(_onSseChanged);
    _sseClient?.dispose();
    super.dispose();
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sentin8Spacing.lg, vertical: Sentin8Spacing.sm),
        child: Row(
          children: [
            Icon(Icons.notifications_outlined, color: Sentin8Colors.primary, size: 20),
            const SizedBox(width: Sentin8Spacing.sm),
            Text('Messages', style: Sentin8Text.bodyMedium.copyWith(color: Sentin8Colors.primary)),
            const Spacer(),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Sentin8Colors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;
  final ValueChanged<String> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == route;
    return ListTile(
      leading: Icon(icon, color: isActive ? Sentin8Colors.primary : Sentin8Colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Sentin8Colors.primary : Sentin8Colors.textPrimary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: isActive,
      selectedTileColor: Sentin8Colors.primary.withValues(alpha: 0.08),
      onTap: () => onTap(route),
    );
  }
}

class _UserMenu extends StatelessWidget {
  final EBankContext appContext;

  const _UserMenu({required this.appContext});

  @override
  Widget build(BuildContext context) {
    final user = appContext.auth.user;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Sentin8Colors.primary,
        child: Text(
          user?.displayName?.isNotEmpty == true
              ? user!.displayName![0].toUpperCase()
              : user?.email.isNotEmpty == true
                  ? user!.email[0].toUpperCase()
                  : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(user?.displayName ?? user?.email ?? 'User', style: Sentin8Text.bodyMedium),
      trailing: IconButton(
        icon: const Icon(Icons.logout, color: Sentin8Colors.textSecondary),
        onPressed: () => appContext.auth.signOut(),
        tooltip: 'Sign Out',
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Sentin8Colors.error),
            SizedBox(height: Sentin8Spacing.md),
            Text('Access Denied', style: Sentin8Text.headlineMedium),
            SizedBox(height: Sentin8Spacing.sm),
            Text('You do not have permission to access this page.',
                style: Sentin8Text.bodyMedium),
          ],
        ),
      ),
    );
  }
}