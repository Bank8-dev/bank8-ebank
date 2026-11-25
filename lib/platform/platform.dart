// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// App-level platform seam - selection point.
//
// eBank was written as a browser app and called `package:web` directly from
// four places. That is fine for the web build and fatal for Android: the whole
// `package:web` library, including `dart:js_interop`, is web-only, so the
// native target cannot compile it at all.
//
// Each concern now has a `_web` / `_io` pair behind a conditional export:
//
//   * [appOrigin]        - where the runtime context is fetched from
//   * [redirectToUrl]    - the OAuth redirect (address bar vs. handoff)
//   * [openExternalUrl]  - opening a message link
//   * [watchBrowserBack] - the browser back button (web only)
//
// `dart.library.js_interop` is the predicate: `dart.library.html` no longer
// distinguishes modern web from wasm.

export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
