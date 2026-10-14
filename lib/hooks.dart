// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank hooks — Sentin8 Flutter SDK hooks adapted for eBank's BFF proxy pattern.
// Data hooks over the BFF proxy clients (accounts, balances, transactions,
// payments, payees).
//
// These hooks wrap the EBankServices (BFF proxy) and provide reactive state
// management using ChangeNotifier. Each hook fetches data via BFF proxy routes
// which route to the corresponding Sentin8 backend service.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'services.dart';

/// Base state for data-fetching hooks.
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

/// useAccounts — fetch customer accounts from Ledger via BFF proxy.
/// Account list via BFF → Ledger GET /v1/accounts.
class AccountsHook extends ChangeNotifier {
  final BffApiClient ledger;

  DataState<List<Map<String, dynamic>>> _state = const DataState();

  AccountsHook(this.ledger);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get accounts => _state.data ?? [];

  Future<void> fetch() async {
    _state = DataState<List<Map<String, dynamic>>>(isLoading: true);
    notifyListeners();
    try {
      final response = await ledger.get('/v1/accounts');
      if (response.isSuccess && response.data != null) {
        final accounts = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _state = DataState<List<Map<String, dynamic>>>(data: accounts);
      } else {
        _state = DataState<List<Map<String, dynamic>>>(data: []);
      }
    } catch (e) {
      _state = DataState<List<Map<String, dynamic>>>(error: e.toString());
    }
    notifyListeners();
  }
}

/// useBalances — fetch account balances from Ledger via BFF proxy.
/// Balances via BFF → Ledger GET /v1/accounts/{id}/balances.
class BalancesHook extends ChangeNotifier {
  final BffApiClient ledger;
  final String accountId;

  DataState<Map<String, dynamic>> _state = const DataState();

  BalancesHook(this.ledger, this.accountId);

  DataState<Map<String, dynamic>> get state => _state;

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      final response = await ledger.get('/v1/accounts/$accountId/balances');
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

/// useTransactions — fetch transaction history for an account.
/// Transactions via BFF → Ledger GET /v1/accounts/{id}/transactions.
class TransactionsHook extends ChangeNotifier {
  final BffApiClient ledger;
  final String accountId;

  DataState<List<Map<String, dynamic>>> _state = const DataState();
  String? _nextPageKey;
  List<Map<String, dynamic>> _allTransactions = [];

  TransactionsHook(this.ledger, this.accountId);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get transactions => _allTransactions;
  bool get hasMore => _nextPageKey != null;

  Future<void> fetch({DateTime? startDate, DateTime? endDate}) async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    _allTransactions = [];
    _nextPageKey = null;

    try {
      final params = <String, String>{};
      if (startDate != null) params['startDate'] = startDate.toIso8601String();
      if (endDate != null) params['endDate'] = endDate.toIso8601String();

      final response = await ledger.get('/v1/accounts/$accountId/transactions', queryParams: params);
      if (response.isSuccess && response.data != null) {
        final txns = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _allTransactions = txns;
        _state = DataState(data: _allTransactions);
      } else {
        _state = const DataState(data: []);
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    try {
      final response = await ledger.get(
        '/v1/accounts/$accountId/transactions',
        queryParams: {'pageKey': _nextPageKey!},
      );
      if (response.isSuccess && response.data != null) {
        final txns = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _allTransactions = [..._allTransactions, ...txns];
        _state = DataState(data: _allTransactions);
        notifyListeners();
      }
    } catch (_) {}
  }
}

/// usePayments — fetch payment history from Payments via BFF proxy.
/// Payments via BFF → Payments GET /v1/payments.
class PaymentsHook extends ChangeNotifier {
  final BffApiClient payments;

  DataState<List<Map<String, dynamic>>> _state = const DataState();

  PaymentsHook(this.payments);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get paymentList => _state.data ?? [];

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      final response = await payments.get('/v1/payments');
      if (response.isSuccess && response.data != null) {
        final payments = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _state = DataState(data: payments);
      } else {
        _state = const DataState(data: []);
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }
}

/// usePayees — fetch payee list from Payments via BFF proxy.
/// Payees via BFF → Payments GET /v1/account-links.
class PayeesHook extends ChangeNotifier {
  final BffApiClient payments;

  DataState<List<Map<String, dynamic>>> _state = const DataState();

  PayeesHook(this.payments);

  DataState<List<Map<String, dynamic>>> get state => _state;
  List<Map<String, dynamic>> get payees => _state.data ?? [];

  Future<void> fetch() async {
    _state = const DataState(isLoading: true);
    notifyListeners();
    try {
      final response = await payments.get('/v1/account-links');
      if (response.isSuccess && response.data != null) {
        final payees = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _state = DataState(data: payees);
      } else {
        _state = const DataState(data: []);
      }
    } catch (e) {
      _state = DataState(error: e.toString());
    }
    notifyListeners();
  }
}