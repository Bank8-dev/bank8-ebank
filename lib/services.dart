// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank services — BFF proxy access layer
// BFF proxy routes for Ledger, Payments, FDX, DB, Storage.
// x-sentin8-correlation-id propagation on every proxy call.
//
// BffApiClient and ApiResponse are re-exported from sentin8.
// EBankServices is app-specific (defines which services eBank uses).

// Re-export shared types from the package.
export 'package:sentin8/sentin8.dart'
    show BffApiClient, ApiResponse, generateCorrelationId;

import 'package:sentin8/sentin8.dart';

/// Centralized service registry for eBank.
///
/// Provides typed API clients for each backend service, all routed through BFF.
/// The [csrfToken] is passed from the AuthProvider for mutating requests.
class EBankServices {
  final BffApiClient ledger;
  final BffApiClient payments;
  final BffApiClient fdx;
  final BffApiClient db;
  final BffApiClient storage;
  final BffApiClient post;

  EBankServices._({
    required this.ledger,
    required this.payments,
    required this.fdx,
    required this.db,
    required this.storage,
    required this.post,
  });

  /// Create EBankServices from runtime context + auth state.
  factory EBankServices({
    required String bffBaseUrl,
    String? csrfToken,
    String? correlationId,
  }) {
    final base = bffBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return EBankServices._(
      ledger: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-ledger', csrfToken: csrfToken, correlationId: correlationId),
      payments: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-payments', csrfToken: csrfToken, correlationId: correlationId),
      fdx: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-fdx', csrfToken: csrfToken, correlationId: correlationId),
      db: BffApiClient(bffBaseUrl: base, serviceName: 'db', csrfToken: csrfToken, correlationId: correlationId),
      storage: BffApiClient(bffBaseUrl: base, serviceName: 'storage', csrfToken: csrfToken, correlationId: correlationId),
      post: BffApiClient(bffBaseUrl: base, serviceName: 'post', csrfToken: csrfToken, correlationId: correlationId),
    );
  }
}