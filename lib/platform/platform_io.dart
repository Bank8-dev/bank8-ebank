// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// App-level platform seam - native implementation (Android / iOS / desktop).
//
// Native has no address bar and no browser back button, so each web concern
// becomes an explicit app decision:
//
//   * origin        - the instance host established at enrollment (WS9), read
//                     from disk. There is NO fallback: an app that has not been
//                     pointed at an instance must show the pairing screen.
//   * redirect      - the OAuth flow runs in the system browser (WS1 handoff);
//                     the address-bar assignment has no native equivalent.
//   * link opening  - handed to the OS via url_launcher.
//   * back button   - the platform's own gesture/back key, not a URL event.

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// File holding the enrolled instance origin.
///
/// WS9 replaces this with a Keystore-sealed record carrying the assurance tier
/// and a hash of the origin (see `docs/06-runtime-enrollment.md` §5). Until
/// then it is a plain file: enough to boot on a device, not enough to ship.
const _originFileName = 'enrolled_origin.txt';

File? _cachedOriginFile;

Future<File> _originFile() async {
  final dir = await getApplicationSupportDirectory();
  return _cachedOriginFile ??= File('${dir.path}/$_originFileName');
}

/// Read a previously enrolled origin, or `null` when the app has not been
/// pointed at an instance yet.
String? get appOrigin {
  // Synchronous accessor: the value is primed by [loadAppOrigin] at start-up.
  return _primedOrigin;
}

String? _primedOrigin;

/// Load the persisted origin into [appOrigin]. Call once before bootstrap.
Future<String?> loadAppOrigin() async {
  try {
    final file = await _originFile();
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    if (value.isEmpty) return null;
    _primedOrigin = value;
    return value;
  } catch (_) {
    return null;
  }
}

/// Persist the instance origin (enrollment). Returns false when the value is
/// not a plain https origin.
Future<bool> saveAppOrigin(String origin) async {
  final uri = Uri.tryParse(origin.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  final normalised = 'https://${uri.host}';
  final file = await _originFile();
  await file.writeAsString(normalised);
  _primedOrigin = normalised;
  return true;
}

/// Clear the enrollment (sign-out + re-enroll).
Future<void> clearAppOrigin() async {
  final file = await _originFile();
  if (await file.exists()) await file.delete();
  _primedOrigin = null;
}

/// OAuth redirect.
///
/// On native the flow completes in the system browser and returns through the
/// `com.bank8.ebank` deep link (WS1). Opening the URL externally is the closest
/// correct behaviour until the handoff handler lands; assigning an address bar
/// is impossible.
void redirectToUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Open [url] in whatever app the OS chooses.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// No browser history on native: the back button is the platform's gesture and
/// is handled with `PopScope` in the shell.
Stream<void>? get browserBackEvents => null;
