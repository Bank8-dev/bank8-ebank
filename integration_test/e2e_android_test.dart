// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// Android e2e - the native leg of the bank8 e2e suite.
//
// Run through `scripts/android-e2e.mjs` (or `make test-android`), which supplies
// the instance origin and the device id. This file contains no hostname: the
// origin is a `--dart-define` so the SAME scenario runs against any instance,
// which is the whole point of runtime enrollment.
//
// What this covers that the web leg cannot:
//   * the app starts on an Android device at all (no browser, no DOM);
//   * the enrollment screen is the first-run state, and it validates;
//   * bootstrap reaches the real instance over TLS from the device;
//   * failures fail CLOSED - an unreachable host shows the error page rather
//     than silently degrading to a localhost default.
//
// What it deliberately does not cover yet: session acquisition. The handoff
// client (deep-link capture + /auth/native/exchange) is the next workstream;
// until it lands the app stops at the landing page after a successful
// bootstrap, and this test asserts exactly that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ebank/main.dart' as app;
import 'package:ebank/platform/platform.dart';

/// The instance origin, supplied by the runner.
const _appOrigin = String.fromEnvironment('E2E_APP_ORIGIN');

/// When `1`, a successful bootstrap against the live instance is REQUIRED.
///
/// Default is `0`: an unreachable backend is a legitimate environment, and the
/// test then asserts the fail-closed path instead. That keeps the suite honest
/// - it reports which of the two outcomes happened rather than pretending.
const _expectReachable = String.fromEnvironment('E2E_EXPECT_REACHABLE') == '1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Each test mounts its OWN app root. `app.main()` calls `runApp`, and calling
  // it repeatedly in one process stacks app instances - a tear-down in one test
  // then trips `setState after dispose` inside another's in-flight bootstrap.
  // Mounting explicitly keeps the tests independent.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const app.EBankApp());
    await tester.pump();
  }

  group('eBank Android e2e', () {
    testWidgets('starts on the device and shows a real screen', (tester) async {
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'the app must render a Scaffold on first frame');
    });

    testWidgets('enrollment is the first-run state when no origin is stored',
        (tester) async {
      await clearAppOrigin();
      expect(appOrigin, isNull,
          reason: 'a cleared enrollment must not resurrect a default origin');

      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Connect to your bank'), findsOneWidget,
          reason: 'an unenrolled install must show the pairing screen');
    });

    testWidgets('rejects a non-https origin', (tester) async {
      await clearAppOrigin();
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField).first, 'http://evil.example');
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('not a valid https'), findsOneWidget,
          reason: 'a plaintext origin must be refused');
      expect(appOrigin, isNull, reason: 'and nothing may be persisted');
    });

    testWidgets('enrolls to the supplied instance origin', (tester) async {
      expect(_appOrigin, isNotEmpty,
          reason: 'run via scripts/android-e2e.mjs, which supplies E2E_APP_ORIGIN');

      await clearAppOrigin();
      final saved = await saveAppOrigin(_appOrigin);
      expect(saved, isTrue);
      expect(appOrigin, _appOrigin);
    });

    testWidgets('bootstrap against the live instance, or fail closed',
        (tester) async {
      expect(_appOrigin, isNotEmpty);

      await clearAppOrigin();
      await saveAppOrigin(_appOrigin);

      await pumpApp(tester);

      // Poll for a settled outcome instead of a fixed sleep: the fetch either
      // resolves (past the pairing screen) or fails (the error page).
      var failedClosed = false;
      var pastPairing = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        failedClosed =
            find.textContaining('Unable to start').evaluate().isNotEmpty;
        pastPairing = find.text('Connect to your bank').evaluate().isEmpty;
        if (failedClosed || pastPairing) break;
      }

      if (_expectReachable) {
        expect(failedClosed, isFalse,
            reason: 'E2E_EXPECT_REACHABLE=1 but bootstrap failed - the device '
                'could not reach $_appOrigin. Check DNS/TLS from the device.');
        expect(pastPairing, isTrue);
      } else {
        // Either outcome is acceptable, but the app must never sit in a broken
        // state: it either bootstrapped or it showed the error page.
        expect(failedClosed || pastPairing, isTrue,
            reason: 'bootstrap must resolve to a visible outcome, never hang');
        // Report which happened, so a green run is never ambiguous.
        // ignore: avoid_print
        print(failedClosed
            ? '  ⓘ bootstrap failed closed (device could not reach $_appOrigin)'
            : '  ⓘ bootstrap succeeded against $_appOrigin');
      }
    });
  });
}
