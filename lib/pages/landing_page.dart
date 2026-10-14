// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank landing page — delegates to sentin8's LandingPage.
//
// The shared LandingPage takes runtimeContext + auth separately.
// eBank's EBankContext wraps both, so we unpack them here.
import 'package:flutter/material.dart';
import 'package:sentin8/sentin8.dart' as s8;
import '../app_context.dart';

/// Landing page shown when the user is not signed in.
/// Delegates to the shared [s8.LandingPage] from sentin8.
class LandingPage extends StatelessWidget {
  final EBankContext appContext;

  const LandingPage({super.key, required this.appContext});

  @override
  Widget build(BuildContext context) {
    return s8.LandingPage(
      runtimeContext: appContext.runtimeContext,
      auth: appContext.auth,
      descriptionText: appContext.runtimeContext.instanceDescription.isNotEmpty
          ? appContext.runtimeContext.instanceDescription
          : 'Your full-service digital bank. Manage accounts, '
            'make transfers, and share data securely.',
    );
  }
}