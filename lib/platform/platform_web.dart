// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// App-level platform seam - browser implementation.

// ignore: avoid_web_libraries_in_flutter
import 'dart:async';

// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// The app's own origin.
///
/// Requests must go to this exact origin so the TLS proxy injects the correct
/// `X-Sentin8-Hostname` and the runtime context resolves to *this* instance.
String? get appOrigin => web.window.location.origin;

/// No-op on web: the origin comes from the address bar, so there is nothing to
/// load. Present for signature parity with the native implementation - the
/// shared `main()` calls it unconditionally.
Future<String?> loadAppOrigin() async => appOrigin;

/// Not applicable on web: the browser cannot be re-pointed at another origin by
/// the app. Always false so the enrollment screen reports the failure honestly
/// if it is ever reached. (It cannot be in practice - `appOrigin` is never
/// null in a browser.)
Future<bool> saveAppOrigin(String origin) async => false;

/// No-op on web: there is no persisted enrollment to clear.
Future<void> clearAppOrigin() async {}

/// Navigate the browser to [url] - the OAuth sign-in/sign-up handoff.
void redirectToUrl(String url) {
  web.window.location.href = url;
}

/// Open [url] in a new browser tab.
Future<bool> openExternalUrl(String url) async {
  web.window.open(url, '_blank');
  return true;
}

/// Listen to browser back/forward. Returns `null` where the platform has no
/// such concept.
Stream<void>? get browserBackEvents => web.window.onPopState;
