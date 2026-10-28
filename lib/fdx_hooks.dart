// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank FDX hooks — FDX Data Provider API access via BFF proxy.
// Recipient-style FDX hooks are shared with eOpenCA (openfin8-eopenca);
// eBank uses the provider-side surface (consents, capability, recipients).
//
// eBank is an FDX Data Provider. FDX hosts the /fdx/v6 provider routes,
// enforces consent, and maps data from Ledger/Payments.
// eBank's Flutter app uses these hooks for the customer-facing consent
// management UI (view consents, revoke consent) and admin FDX management.
// External recipients call FDX directly — eBank does not serve provider APIs.

import 'package:flutter/foundation.dart';
import 'services.dart';

/// useFdxConsents — fetch customer's FDX consents (as a data provider's customer).
/// Consents via BFF → FDX consents endpoint.
class FdxConsentsHook extends ChangeNotifier {
  final BffApiClient fdx;

  DataState<List<Map<String, dynamic>>> _state = const DataState();

  FdxConsentsHook(this.fdx);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get consents => _state.data ?? [];

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      final response = await fdx.get('/fdx/v6/consents');
      if (response.isSuccess && response.data != null) {
        final consents = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _state = DataState(data: consents);
      } else {
        _state = const DataState(data: []);
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }

  /// Revoke a consent.
  Future<bool> revoke(String consentId, {String reason = 'USER_ACTION'}) async {
    final idempotencyKey = 'rvk-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final response = await fdx.put(
        '/fdx/v6/consents/$consentId/revocation',
        body: {
          'reason': reason,
          'idempotencyKey': idempotencyKey,
        },
      );
      if (response.isSuccess) {
        await fetch(); // Refresh list
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// useFdxProviders — fetch FDX provider info for admin management.
/// Providers via BFF → FDX providers endpoint.
class FdxProvidersHook extends ChangeNotifier {
  final BffApiClient fdx;

  DataState<Map<String, dynamic>> _state = const DataState();

  FdxProvidersHook(this.fdx);

  DataState<Map<String, dynamic>> get state => _state;

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      final response = await fdx.get('/fdx/v6/capability');
      if (response.isSuccess && response.data != null) {
        _state = DataState(data: response.data!);
      } else {
        _state = const DataState(data: {});
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }
}

/// FDX recipient registration hook for admin use.
/// Recipient registration through FDX.
class FdxRecipientsHook extends ChangeNotifier {
  final BffApiClient fdx;

  DataState<List<Map<String, dynamic>>> _state = const DataState();

  FdxRecipientsHook(this.fdx);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get recipients => _state.data ?? [];

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      // FDX admin API for recipient registration overview
      final response = await fdx.get('/v1/admin/recipients');
      if (response.isSuccess && response.data != null) {
        final recipients = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _state = DataState(data: recipients);
      } else {
        _state = const DataState(data: []);
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }
}

/// Base data state for FDX hooks.
class DataState<T> {
  final T? data;
  final bool isLoading;
  final String? error;

  const DataState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  bool get hasData => data != null;
}