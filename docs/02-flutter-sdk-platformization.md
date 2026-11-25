# WS3 — Sentin8:Flutter SDK Platformization

Status: **Core split landed — VM gate green** (see §9 for what remains)
Repo: `sentin8-flutter` (platform package, shared by 22 Flutter apps in the tree)
Effort: **4.5 person-weeks** (§7 breakdown; includes test debt that predates Android)
Blocks: WS4 (Android app), WS5 (responsive UI verification), WS6
Risk: **highest regression risk in the programme** — every Flutter app in the
tree consumes this package

---

## 1. Problem

`sentin8-flutter` is web-only in practice, despite being described as
"native + web" in its own `README.md`. It has **no** `*.web.dart` / `*.io.dart`
pairs. Eight files block a native build:

| File | Browser API used | Native failure |
|---|---|---|
| `src/bff/bff_client.dart` | `web.window.fetch`, `web.RequestInit(credentials:'include')`, `web.Headers`, `web.Response` (lines 16, 75–167) | does not compile |
| `src/bff_auth/auth_provider.dart` | same (lines 19, 140–215) | does not compile |
| `src/bootstrap/runtime_context.dart` | `web.window.location.hostname` (line 16, used by `_getCurrentHostname`) | does not compile |
| `src/realtime/sse_client.dart` | `web.EventSource`, `web.EventSourceInit`, `web.MessageEvent` (lines 21, 28, 47–49, 70, 86) | does not compile; also `connect()` returns early off-web |
| `src/realtime/ws_client.dart` | `web.WebSocket` (lines 16, 20, 48) | does not compile |
| `src/routing/url_router.dart` | `web.window.history`, `web.window.location.hash` (line 17) | compiles only because every function is guarded by `if (!kIsWeb) return` — **but** `package:web` still fails at compile time on the VM |
| `src/rfw/rfw_page.dart` | `package:web/web.dart` imported, **never used** (line 22) | does not compile (the barrel exports it, so it is always compiled) |
| **`src/rfw/rfw_renderer.dart`** | **`dart:html` for a file input + `FileReader`** (lines 12, 1299, 1308) | **does not compile** |

The last row was **missed by the first pass of this document**, which listed
seven files. It was found by building the VM gate and reading the error: the
initial inventory was assembled by grepping for `package:web` / `dart:js_interop`,
and `dart:html` is a sibling import that the grep did not cover. Lesson recorded
below in §2: the authoritative inventory is **the VM gate's error output**, not a
pattern search.

`lib/sentin8.dart` exports all of these unconditionally, so any app that has
`import 'package:sentin8/sentin8.dart'` inherits the problem even if it uses
none of the affected classes (`bank8-ebank` does not use RFW or the WS client).

Verified failure:

```text
$ dart run probe.dart          # imports package:web
Error: Dart library 'dart:js_interop' is not available on this platform.
```

Package: `web 1.1.2`. `dart:js_interop` is a web-only SDK library; no
conditional import can make it available on the VM.

---

## 2. Strategy

**Do not fork the package.** Introduce platform-specific implementation files
behind conditional exports, keep every public API signature identical, and
prove the web build is unchanged at each step.

```text
lib/src/bff/
  bff_client.dart              ← facade: `export 'bff_client_io.dart'
                                  if (dart.library.js_interop) 'bff_client_web.dart';`
  bff_client_core.dart         ← shared: ApiResponse, URL building, header maps,
                                  response-to-ApiResponse mapping, envelope unwrap
  bff_client_web.dart          ← `web.window.fetch` + credentials:'include'
  bff_client_io.dart           ← dart:io / package:http + cookie jar
```

Selection predicate: **`dart.library.js_interop`** (not `dart.library.html`,
which no longer distinguishes modern web from wasm; not `kIsWeb`, which is a
runtime check and cannot save a compile error).

Order of work: **lowest risk first**, so each step is independently shippable.

### The gate that defines "done"

**`flutter test <probe>` is the authority, not a grep.** A test file that imports
`package:sentin8/sentin8.dart` and asserts one trivial thing compiles for the
Flutter VM (the native target) and fails loudly on any web-only import in the
barrel's transitive closure:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentin8/sentin8.dart';

void main() {
  test('SDK barrel compiles for the VM (non-web)', () {
    expect(const BootstrapException('probe', 'detail').message, 'probe');
  });
}
```

Two things this catches that pattern-searching cannot:

- sibling imports of the web family (`dart:html`, `dart:js`, `dart:js_util`);
- a web-only import pulled in transitively through an export chain.

Run it before and after every step. Before the split it failed with
`Dart library 'dart:js_interop' is not available on this platform`; after, it
passes. **Do not** use `dart compile exe` as the probe - Flutter packages need
`dart:ui` and it fails on `flutter_svg` before reaching the real problem.

---

## 3. Per-file plan

### 3.1 `rfw_page.dart` — delete the dead import (0.5 day, zero risk)

`package:web/web.dart` is imported and never referenced. Delete line 22.
Verify `flutter build web` output hash is unchanged modulo build metadata.
This alone removes one compile blocker for free.

### 3.2 `url_router.dart` — already runtime-guarded, needs compile isolation (0.5 day)

All five functions begin with `if (!kIsWeb) return`. The only problem is the
import. Two options:

- **(a)** split into `url_router_web.dart` / `url_router_io.dart` where the IO
  file is a no-op set of the same five functions. Preserves today's semantics
  exactly.
- **(b)** keep one file and take a router-agnostic callback injected at app
  start.

Choose **(a)** for WS3 — it is a pure mechanical change and keeps the web
bytes identical. WS5 revisits routing properly (the Android back button needs
real behaviour, which is an app concern, not an SDK one).

### 3.3 `runtime_context.dart` — remove the silent localhost default (1 day)

`_getCurrentHostname()` does:

```dart
try { return web.window.location.hostname; } catch (_) { return 'localhost'; }
```

Two defects for native:

1. It does not compile.
2. The `catch` → `'localhost'` fallback is **fail-open**. On Android this returns
   `'localhost'` and the app sends `X-Sentin8-Hostname: localhost` to the App
   service, which either errors or (worse) resolves the wrong instance.

Fix: `fetchRuntimeContext` already accepts `appBaseUrl`. Make the hostname an
explicit parameter:

```dart
Future<AppRuntimeContext> fetchRuntimeContext({
  String? appBaseUrl,
  String? hostname,          // NEW: required on native, derived on web
  String logPrefix = 'App',
});
```

- `runtime_context_web.dart`: `hostname ?? web.window.location.hostname`
- `runtime_context_io.dart`: `hostname` is **required**; throw
  `BootstrapException` if absent. No localhost default anywhere.

This is a **behaviour change for anyone relying on the fallback**, so grep the
tree for callers without an explicit host before merging. `bank8-ebank` passes
`appBaseUrl` but relies on the derived hostname (`main.dart:56`), so WS4 must
also pass `--dart-define=SENTIN8_HOST` (the app's own origin host).

### 3.4 `bff_client.dart` — the core change (5 days)

Extract `bff_client_core.dart` for everything that is platform-neutral:

- `_buildUrl()`, `_headers()`, envelope unwrapping in `_webResponseToApi`
  (rename to `parseResponse`), `ApiResponse`
- the current `_webResponseToApi` logic becomes `ApiResponse.fromStatusBody(status, rawBody)`
  shared by both transports

**Web implementation** — unchanged behaviour: `web.window.fetch` with
`credentials: 'include'` for all four verbs.

**IO implementation** — needs a real cookie jar, because `package:http`'s
`get`/`post` do not persist `Set-Cookie`:

`bff_client_io.dart`
```dart
// dio + cookie_jar + persistent_cookie (or http + a hand-rolled jar)
final _dio = Dio(BaseOptions(baseUrl: bffBaseUrl))
  ..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient()..badCertificateCallback = ...);
final _jar = PersistCookieJar(storage: FileStorage('$docDir/bff_cookies'));
_dio.interceptors.add(CookieManager(_jar));
```

Bearer mode (WS1): when a session token is present, send
`Authorization: Bearer <token>` and skip the cookie entirely. Keep both
transports selectable at construction so the web build never gains a bearer
path and the app never depends on cookies:

```dart
BffApiClient({
  required this.bffBaseUrl,
  required this.serviceName,
  this.csrfToken,
  this.correlationId,
  this.delegationId,
  this.sessionToken,        // NEW, native only
})
```

Dependencies to add: `dio`, `cookie_jar`, `path_provider` (or `http` +
`cookie_jar`). All are pure-Dart/IO and must be **conditional imports** too, or
the web build will try to tree-shake `dart:io`. `cookie_jar`'s `PersistCookieJar`
uses `dart:io` — so the IO file owns it, and the web file never imports it.
`pubspec.yaml` gains the deps unconditionally (that is fine; they are only
*linked* by the IO file).

### 3.5 `auth_provider.dart` — handoff-aware, platform-split (4 days)

Behaviour must diverge meaningfully, not mechanically:

| Concern | Web | Android |
|---|---|---|
| Sign-in | `window.location.href = '{bff}/auth/login'` | `POST /auth/native/start` → open Custom Tab → capture `com.bank8.ebank:/oauth2redirect?handoff=` → `POST /auth/native/exchange` |
| Session read | `GET /auth/session` (cookie) | `GET /auth/session` (bearer) |
| Sign-out | `POST /auth/sign-out` (cookie) | `POST /auth/sign-out` (bearer) + clear Keystore |
| `onRedirect` | assigns `window.location.href` | routes to the deep-link handler |

API shape stays: `BffAuthProvider({bffBaseUrl, authDomain, onRedirect})`, plus a
new injectable `NativeAuthHandler` on the IO side. The web file does not know
the handler exists.

`app_context.dart:44-48` currently wires
`auth.onRedirect = (url) => web.window.location.href = url;`. That line moves
into the platform split (the app's own file is not part of the SDK, so WS4
handles it).

### 3.6 `sse_client.dart` — fix the dead realtime path (3 days)

Two independent defects:

1. **Compile**: `web.EventSource`, `web.EventSourceInit`, `web.MessageEvent`.
2. **Logic**: `void connect() { if (!kIsWeb) return; … }` returns **before**
   `startPolling()`. On Android today, neither SSE nor the 5-second unread poll
   runs. Notifications would silently never appear.

Plan:

- `sse_client_core.dart`: the `ChangeNotifier` state, unread counting, reconnect
  scheduling, `startPolling`/`stopPolling`. Shared.
- `sse_client_web.dart`: `web.EventSource` as today.
- `sse_client_io.dart`: `http.Client().send(Request)` streaming parser — read
  `stream` line by line, parse `event:` / `data:` frames, dispatch to the same
  handlers. Send `Authorization: Bearer` (WS1) since `EventSource` has no header
  support but a raw HTTP stream does.
- `connect()` in the IO file **must** call `startPolling()` unconditionally and
  treat SSE as an enhancement over polling — not a replacement.

Fallback contract to document and test: SSE unavailable → poll every 5s (today's
`startPolling`), SSE available → poll stays on as a low-frequency safety net
(bump to 60s) to cover missed frames.

### 3.7 `ws_client.dart` — compile-only for eBank, real work if others follow (1–4 days)

`sentin8.dart` exports it unconditionally, so it **must compile on the VM** for
any app to build for Android.

`sentin8-flutter` itself never uses it, and `bank8-ebank` does not reference
`BffWebSocket` (verified). But it **does** have real consumers in the tree:

| Consumer | File |
|---|---|
| `bank8-eteller` | `lib/bff_ws.dart`, `lib/pages/eteller_shell.dart:91` |
| `sentin8-dash` | `lib/bff_ws.dart`, `organization_home_page.dart`, `organization_picker_page.dart`, `widgets/metrics_table.dart` |

This splits the decision:

- **For eBank (this programme):** a compiling IO implementation is sufficient.
  Use `dart:io`'s `WebSocket.connect(url, headers: {'Authorization': 'Bearer …'})`,
  which is straightforwardly better than the web version because headers are
  possible. Roughly half a day — the connect/reconnect/frame-dispatch shape
  mirrors the web file.
- **For eTeller/Dash (not in scope):** those apps need the IO path to be
  *functional*, not just compiling. That is a genuine ~1.5 day addition and it
  should be scheduled only when one of them is ported.

Do **not** ship a `throw UnsupportedError('use SSE on native')` stub and leave it:
because the two consumer apps exist, a stub is a latent runtime trap for the next
person who ports an app. A working IO implementation is cheap enough here to be
the right call.

Estimated as **1 day** in §7 for the eBank-scope version; add **+1.5 days** if
eTeller/Dash mobile is committed at the same time.

### 3.8 `sentin8.dart` barrel

Keep one barrel. Exports stay identical because the facade files present the
same symbols. Add a compile-time guard test (see §5) that builds a trivial app
for both targets.

### 3.9 Theme/assets (1 day)

- `theme_builder` does not set a `fontFamily` anywhere; `runtime_context`
  carries one but it is unused. `google_fonts` is declared in `pubspec.yaml` but
  **not referenced** in `lib/` — so no runtime font fetch actually happens today.
  Verify with `grep -rn GoogleFonts lib` before assuming; if a future
  `fontFamily` path is added, bundle Inter as an asset for native (avoids a
  first-launch network dependency and a Play Store "app downloads fonts"
  privacy question).
- `networkLogo()` uses `SvgPicture.network` / `Image.network` — both work on
  Android, but must be given an explicit `errorBuilder` (already present) and
  should go through a cache (`cached_network_image` or Flutter's built-in image
  cache) so the shell does not re-fetch on every rebuild.

---

## 4. Dependency and pubspec impact

```yaml
dependencies:
  sentin8:
    path: …
  # unchanged for web; linked only by *_io.dart files
  dio: ^5
  cookie_jar: ^4
  path_provider: ^2
```

Concern: `sentin8-flutter` is consumed by 22 Flutter apps in the tree. Adding
three IO-only dependencies to the shared package inflates every app's dependency
graph even though the web build tree-shakes them.

Alternative worth evaluating in review: keep `sentin8-flutter` dependency-free
and implement the IO transport with `dart:io`'s `HttpClient` plus a small
in-memory cookie jar (~120 lines). `HttpClient` handles `Set-Cookie` via
`response.cookies` and lets you send `Cookie` headers directly — enough for
`bff-session`, avoids three deps, and gives full control over the bearer path.
**Recommendation: do this.** The jar is one class, and the BFF sets exactly one
cookie the app needs.

---

## 5. Regression gate (non-negotiable)

Every step must pass, in this order:

1. **VM compile gate** (see §2): `flutter test test/vm_compile_probe_test.dart`.
   This is the *first* gate - it is the only one that proves the native target
   compiles at all.
2. `flutter analyze` - must not exceed the pre-existing issue count (19 at the
   time of writing; all `material.dart` deprecations and two pre-existing
   `rfw_renderer` warnings). A *new* warning is a regression.
3. `flutter test` for the package.
4. `cd bank8-ebank && flutter build web --release --no-tree-shake-icons` - the
   real web consumer must still build. This caught two genuine breakages during
   implementation (see §5.1).
5. `cd bank8-ebank && flutter test` - the consumer's own suite.
6. `cd bank8-ebank && flutter build apk --debug` - the milestone that did not
   exist before.
7. `bank8-ebank` Playwright lifecycle suite (`bank8-e2e`) - the behavioural
   check.

A CI job must run **1-5** on every PR to `sentin8-flutter`; 6-7 stay in the app
and e2e repos.

### 5.1 Findings from implementing the split

Three things the plan did not anticipate, recorded so the remaining workstreams
do not rediscover them:

**a. `flutter analyze` does not validate both platform variants.** It analyses
one target. The web-only files (`*_web.dart`) can be silently broken while
analyze reports clean - which is exactly what happened here: analyze stayed at
18-19 issues while `dart2js` failed on two separate errors. **`flutter build web`
must be in the inner loop**, not only at the end of a step.

**b. `web.Headers.set` cannot be torn off.** Passing it as a method reference
(`headers.forEach(requestHeaders.set)`) is rejected by `dart2js` with
*"Tear-offs of external extension type interop member 'set' are disallowed"*.
Call it inside a closure instead:

```dart
headers?.forEach((key, value) {
  requestHeaders.set(key, value);
});
```

This is a general constraint on `package:web` interop types, not specific to
`Headers`.

**c. Conditional-export halves must keep identical signatures.** The IO
transport needed an optional `sessionToken`; the web transport ignored it, so its
signature did not include it and the *shared call site* failed to compile:

```
auth_provider.dart:149:48: Error: No named parameter with the name 'sessionToken'.
```

Rule: when a shared caller branches on `kIsWeb` but both branches must satisfy
the same call shape, give the **web** implementation the parameter too and
document that it ignores it. Parity of signature, not just of behaviour.

---

## 6. Test debt

`sentin8-flutter` has **no tests** (`find test -name '*.dart'` → empty). The
conditional-import split is exactly the kind of change that needs them. Minimum
set to add in WS3:

| Test | Target |
|---|---|
| `bff_client` URL/header construction | core (shared, runs on VM) |
| Envelope unwrapping (success / bare array / error body) | core |
| `extractSession` behaviour | IO: bearer wins over cookie; both absent → null |
| Cookie jar persistence | IO: `Set-Cookie` on login survives a second request |
| SSE frame parser | IO: split frames across chunks, `event:` + multi-line `data:` |
| SSE fallback | IO: `connect()` with SSE failing still starts polling (regression test for the current bug) |
| `fetchRuntimeContext` without hostname | IO: throws, does not default to localhost |
| Web-unchanged guard | compile-only smoke test |

---

## 7. Task breakdown (4.5 pw)

| # | Task | Days |
|---|---|---|
| 1 | Delete dead `package:web` import in `rfw_page.dart` | 0.5 |
| 2 | `url_router` web/io split (no-op IO) | 1 |
| 3 | `runtime_context` hostname parameter + remove localhost default + audit callers | 2 |
| 4 | `bff_client` core extraction + IO transport (HttpClient + cookie jar) | 5 |
| 5 | `auth_provider` web/io split + `NativeAuthHandler` seam | 4 |
| 6 | `sse_client` core/web/io split + polling fix | 3 |
| 7 | `ws_client` split (IO stub) | 1 |
| 8 | Theme/assets review (fonts, logo caching) | 1 |
| 9 | New tests (§6) | 3 |
| 10 | CI job (analyze/test/build-web/build-apk) + `DESIGN.md`/`README.md` corrections | 2 |
| **Total** | | **22.5 days ≈ 4.5 pw** |

The 4.5 pw includes ~3 days of test debt (§6) that exists independently of
Android. Without it the SDK split is 19.5 days ≈ 3.9 pw — still above a naive
3.5 pw read, because the `bff_client` transport rewrite is genuinely the largest
single item.

---

## 8. Open questions

- Q1: **Resolved.** `BffWebSocket` has two real consumers — `bank8-eteller`
  (`eteller_shell.dart:91`) and `sentin8-dash` (4 files). Neither is in this
  programme's scope, so WS3 ships a functional-but-unexercised IO implementation
  (1 day). If either is ported, add ~1.5 days and a device test.
- Q2: Does any app rely on `_getCurrentHostname()`'s `'localhost'` fallback for
  local dev? If yes, replace with an explicit `--dart-define`, do not keep the
  fallback.
- Q3: `pubspec.yaml` lists `google_fonts` and `flutter_svg` but `lib/` does not
  reference `GoogleFonts`. Confirm dead dependency; remove if so, since it is
  the only thing suggesting runtime font downloads.

---

## 9. Implementation status (2026-11-25)

**Landed.** The core split is in `sentin8-flutter` on `main`, and the three gates
pass:

| Gate | Before | After |
|---|---|---|
| VM compile probe | ❌ `dart:js_interop is not available on this platform` | ✅ **passes** |
| `flutter analyze` | 20 issues | 18 issues (baseline minus two dead imports) |
| `bank8-ebank` web build | ✅ | ✅ `✓ Built build/web` |
| `bank8-ebank` tests | 28 pass | 28 pass |

Files created (each facade keeps the pre-split public API):

| Facade | Core | Web | IO |
|---|---|---|---|
| `bff/bff_client.dart` | `bff_client_core.dart` (`ApiResponse.fromStatusBody`, URL + header builders) | `bff_client_web.dart` (`window.fetch`) | `bff_client_io.dart` (`HttpClient` + Bearer) |
| `bff_auth/auth_provider.dart` | *(state machine stays in the facade)* | `auth_transport_web.dart` | `auth_transport_io.dart` |
| `bootstrap/runtime_context.dart` | — | `hostname_source_web.dart` | `hostname_source_io.dart` |
| `realtime/sse_client.dart` | `sse_client_core.dart` (unread accounting, reconnect, polling) | `sse_client_web.dart` (`EventSource`) | `sse_client_io.dart` (raw HTTP + hand-written SSE parser) |
| `realtime/ws_client.dart` | `ws_client_core.dart` (callbacks, reconnect, event router) | `ws_client_web.dart` | `ws_client_io.dart` (`dart:io` WebSocket + Bearer header) |
| `routing/url_router.dart` | — | `url_router_web.dart` | `url_router_io.dart` (no-op) |
| `rfw/rfw_page.dart` | dead import deleted | — | — |
| `rfw/rfw_renderer.dart` | — | `rfw_file_picker_web.dart` | `rfw_file_picker_io.dart` (returns null + debug note) |

Behavioural changes worth calling out:

- **`NotificationSseClient.connect()` now starts polling on every platform.** The
  pre-split `if (!kIsWeb) return;` also skipped `startPolling()`, so native had
  neither SSE nor the fallback. Native now runs polling plus a real SSE stream.
- **`fetchRuntimeContext` takes an optional `hostname`** and no longer falls back
  to `'localhost'`. On native a missing hostname throws `StateError` (WS9 treats
  that as "show the pairing screen").
- **The IO transports carry the session as `Authorization: Bearer`**, matching
  the WS1 BFF contract. Web is unchanged (`credentials: 'include'`).

**Remaining before WS3 is complete:**

1. The package still has **no unit tests** except the compile probe (§6). The
   SSE parser in `sse_client_io.dart` is the highest-value first target - it is
   hand-written wire parsing with no coverage.
2. `BffWebSocket`'s IO transport is functional but unexercised (no consumer in
   this programme); needs a device test if eTeller/Dash are ever ported.
3. `rfw_file_picker_io.dart` returns `null` — RFW uploads do not work on native.
   Acceptable today (no app needs it) but it is a known gap, not a solution.
4. CI has no job running these gates yet (that is PB-4 / MOB-7).
5. `flutter build apk` has **not** been attempted - there is no `android/` folder
   in `bank8-ebank` yet (that is WS4). The VM gate is the proxy for it.
