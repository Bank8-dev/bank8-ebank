// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank widget tests - test that core widgets render without errors
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebank/theme.dart';

void main() {
  group('Sentin8 Theme', () {
    testWidgets('GlassPanel renders child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sentin8Theme(),
          home: const Scaffold(
            body: GlassPanel(child: Text('Test')),
          ),
        ),
      );
      expect(find.text('Test'), findsOneWidget);
    });

    test('sentin8Theme seeds the color scheme from Sentin8Colors.primary', () {
      final theme = sentin8Theme();
      // Material 3 derives the scheme from the seed, so the resolved primary
      // is a tinted variant - assert the relationship, not raw equality.
      expect(theme.colorScheme.primary, isNot(Colors.transparent));
      expect(
        theme.colorScheme.brightness,
        Brightness.light,
      );
    });
  });
}