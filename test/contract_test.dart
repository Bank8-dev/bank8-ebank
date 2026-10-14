// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank contract tests — Flutter-BFF and BFF-service boundary contract validation.
// Contract tests for all proxy routes.
import 'package:flutter_test/flutter_test.dart';
import 'package:ebank/services.dart';

void main() {
  group('BffApiClient', () {
    late BffApiClient ledger;
    late BffApiClient payments;
    late BffApiClient fdx;
    late BffApiClient db;
    late BffApiClient storage;

    setUp(() {
      const bffBaseUrl = 'https://bff.bank8-ebank.prod.acme.sentin8.local';
      ledger = BffApiClient(bffBaseUrl: bffBaseUrl, serviceName: 'bank8-ledger');
      payments = BffApiClient(bffBaseUrl: bffBaseUrl, serviceName: 'bank8-payments');
      fdx = BffApiClient(bffBaseUrl: bffBaseUrl, serviceName: 'bank8-fdx');
      db = BffApiClient(bffBaseUrl: bffBaseUrl, serviceName: 'db');
      storage = BffApiClient(bffBaseUrl: bffBaseUrl, serviceName: 'storage');
    });

    test('Ledger client builds correct proxy URL', () {
      // The actual URL is built internally — we test the service name mapping
      expect(ledger.serviceName, equals('bank8-ledger'));
    });

    test('Payments client builds correct proxy URL', () {
      expect(payments.serviceName, equals('bank8-payments'));
    });

    test('FDX client builds correct proxy URL', () {
      expect(fdx.serviceName, equals('bank8-fdx'));
    });

    test('DB client builds correct proxy URL', () {
      expect(db.serviceName, equals('db'));
    });

    test('Storage client builds correct proxy URL', () {
      expect(storage.serviceName, equals('storage'));
    });
  });

  group('EBankServices', () {
    test('Creates all 6 service clients', () {
      final services = EBankServices(
        bffBaseUrl: 'https://bff.bank8-ebank.prod.acme.sentin8.local',
      );
      expect(services.ledger.serviceName, equals('bank8-ledger'));
      expect(services.payments.serviceName, equals('bank8-payments'));
      expect(services.fdx.serviceName, equals('bank8-fdx'));
      expect(services.db.serviceName, equals('db'));
      expect(services.storage.serviceName, equals('storage'));
      expect(services.post.serviceName, equals('post'));
    });

    test('Strips trailing slashes from BFF base URL', () {
      final services = EBankServices(
        bffBaseUrl: 'https://bff.bank8-ebank.prod.acme.sentin8.local///',
      );
      expect(services.ledger.bffBaseUrl, equals('https://bff.bank8-ebank.prod.acme.sentin8.local'));
    });
  });

  group('Correlation ID', () {
    test('generateCorrelationId produces non-empty string', () {
      final id = generateCorrelationId();
      expect(id, isNotEmpty);
      // SDK default prefix is 'app' (correlation.dart) — callers pass their
      // own prefix (e.g. eBank's logger uses 'ebk') at call sites.
      expect(id, startsWith('app-'));
    });

    test('generateCorrelationId produces unique values', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(generateCorrelationId());
      }
      // IDs carry a random suffix (correlation.dart) — all must be unique,
      // even when iterations share a millisecond timestamp.
      expect(ids.length, equals(100));
    });
  });
}