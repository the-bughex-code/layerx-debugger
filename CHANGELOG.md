# Changelog

All notable changes to **layerx_debugger** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0

### Fixed

- **Random freeze/crash during navigation (critical).** The log store notified
  its listeners (the floating "Report a bug" pill, the settings tile, the open
  shell) **synchronously**. Any log emitted while a frame was building — a GetX
  controller's `onInit` running while its route builds (`Get.put`/bindings/
  `Get.find` during build), `LayerXLog.screen()` called from `build()`, a nested
  `Navigator`'s initial `didPush` firing inside `initState`, or any
  `FlutterError` reported during a build — ran `setState` on those listeners
  mid-build: *"setState() or markNeedsBuild() called during build."* Worse, the
  framework forwards that failure to `FlutterError.onError`, which is LayerX's
  own crash hook — it re-ingested the error into the same notifier, which threw
  again, recursing without bound: console flooded with error dumps, `debugPrint`
  throttling backed up for minutes, and the stack eventually overflowed. The
  app froze or died mid-navigation with no useful logs. The store now keeps a
  synchronous canonical list but **defers listener notification to a post-frame
  callback whenever a frame is mid-build**, coalescing bursts into one
  notification per frame — every producer phase is now safe, and log floods no
  longer rebuild the FAB once per entry.
- **Crash-handler feedback loops.** `LayerXCrashHandler` now drops errors
  raised *while it is recording an error* (re-entrancy guard), and a throwing
  `onCrash` callback can no longer cascade back into the error hooks.
- **Unbounded duplicate growth.** A repeating error (broken timer/stream)
  accumulated `repeatTimestamps` forever; entries now keep the newest 100
  timestamps while `occurrenceCount` still tracks the true total.
- **Overlay churn on navigation.** The trigger overlay was removed and
  re-inserted after *every* push, pop and replace. Pops can never cover the
  trigger, so they no longer touch the overlay, and queued lifts are
  single-flight — one navigation burst schedules at most one re-insert.
- **Stale navigator use.** `LayerXDebugger.findNavigator` no longer returns the
  route observer's navigator when that navigator is unmounted (e.g. the
  observer was attached to a since-disposed nested navigator), so opening the
  viewer can't push onto a dead navigator.
- **Stacked viewer shells (critical).** The edge-swipe trigger opened the
  viewer on *every* drag update past its 8px threshold — one fast swipe pushed
  several debugger shells, and the back button then appeared broken (each press
  peeled one invisible duplicate). The swipe is now latched once per gesture,
  and every open path (FAB tap, coach bubble, quick menu, edge swipe,
  `LayerXDebugger.openViewer`, the settings tile) claims a single-flight open —
  a double-tap or a tap racing an API callback opens exactly one shell.
- **Per-log list copies in hot paths.** The store's `logs` getter returns a
  defensive copy; the duplicate lookup (which runs on **every** ingest) and the
  badge counts (which run on every FAB rebuild) went through it, turning a
  console flood into O(n²) allocation churn on the UI thread. They now iterate
  the canonical list in place, and the dedup scan stops at the 2-second window
  boundary instead of walking all 500 entries.
- **Frame-monitor callback leak.** `LayerXFrameMonitor.reset()` now detaches
  its timings callback; a reset + re-install cycle no longer double-logs every
  janky frame.
- **Non-Material hosts.** Copy confirmations and the clear-session Undo
  snackbar use `ScaffoldMessenger.maybeOf`, so a Cupertino/WidgetsApp host
  (which has no ScaffoldMessenger) can no longer make a copy or clear action
  throw.

## 1.9.2

### Fixed

- **ANR / hang during navigation (critical).** In debug builds, console capture
  routed every framework/app `debugPrint` line into the log-ingest path, which
  synchronously captured `StackTrace.current` **twice per line**. Apps whose
  logger pretty-prints API payloads emit hundreds of console lines per
  navigation, so a single navigation to a data-heavy screen could block the UI
  thread long enough to trigger an Android **ANR** (SIGQUIT / "Wrote stack traces
  to tombstoned"). Ingest now captures a stack **at most once**, and only for
  entries worth attributing (an explicit error/stack, or `warning`+); the
  high-volume console-capture path skips it entirely. As a hard guard, console
  capture also caps how many lines it ingests per synchronous burst (collapsing
  any overflow into a single summary entry), so it can never block the UI thread
  however chatty the app is. Data-heavy screens no longer hang.

### Changed

- The in-app debugger (shell, detail screen and the floating trigger overlay) is
  now wrapped in its **own self-contained dark Material theme**, so it renders
  consistently on any host — including Cupertino/`WidgetsApp` apps with no
  Material ancestor (fixes a "No Material widget found" crash class for the FAB's
  bottom sheet / popup menu) — and never inherits the host app's theme.

## 1.9.1

### Fixed

- **Log attribution (screen / method) now populates from the stack.** The
  stack-frame parser's SDK-frame filter matched `dart:` as a bare substring,
  which also matched every real app frame — a normal frame path ends in
  `.dart:<line>` (e.g. `package:myapp/home_controller.dart:42`). As a result it
  skipped all app frames and `screenName` / `methodName` were never derived from
  a stack (only file/line resolved). The filter now anchors to the frame's
  location parens (`(dart:`, `(package:flutter/`, `(package:logger/`), so true
  SDK/framework frames are skipped while the first real app frame is attributed
  correctly.

## 1.9.0

### Changed

- **UX P4: accessible to every tester.** Every control now has a ≥48dp touch
  target and a screen-reader label (VoiceOver/TalkBack never announce a bare
  "button"). With OS reduce-motion on, nothing animates perpetually — and even
  without it, the floating button's pulse now fires only when a new problem
  arrives, then rests. A one-time coach mark introduces the "Report a bug"
  button on first run, empty states say plainly that the tool records what
  happened (redo the action in the app — there is no retry button to hunt for),
  and the viewer holds up under 1.5× system text scaling and RTL locales.
  This completes the 1.5.0 → 1.9.0 usability-first redesign arc.

## 1.8.0

### Changed

- **UX P3: calm, readable, accessible.** The Neo-Terminal skin is retired: a
  neutral high-contrast dark palette where every load-bearing text token meets
  WCAG AA (≥4.5:1) — enforced by a contrast unit test — with crashes/fatals as
  the most prominent color in the system. The shell prompt and blinking cursor
  are gone (plain "Debugger" title + honest problem count), monospace is
  reserved for payloads and stack traces, cards/pills/snackbars have visible
  edges, the floating button is now a labeled **"Report a bug"** pill, and the
  edge-swipe affordance is a visible handle.

## 1.7.0

### Changed

- **UX P2: the debugger now tells you whose fault it is.** Every problem card
  leads with a plain-language verdict from the built-in blame engine (e.g.
  "🖥️ Backend Server (5xx Internal Error)"), and opening a problem reads
  top-to-bottom like a bug report: who to assign & why → suggested fix →
  details → what the app sent → what the server answered → journey → collapsed
  technical stack. A persistent **Copy bug report** button (with Prev/Next to
  walk problems) produces a complete, paste-ready ticket. States are honest:
  filtered-empty offers "Clear filters", truly-empty explains the tool records
  (it can't retry), and pausing shows a full-width banner. Friendly labels
  everywhere (🖥 Server Error instead of `server`, relative time instead of
  ISO-8601, "response changed shape" instead of Δ/schema). Slow requests
  (≥800ms, configurable via `LayerXLogStore.slowRequestThresholdMs`) now count
  as problems in every badge and count.

## 1.6.0

### Changed

- **UX P1: the viewer now opens on a Problems inbox.** The 4-tab shell is
  replaced by two segments — **Problems** (a worst-first inbox of errors,
  crashes, warnings, changed responses, and slow requests ≥800ms) and
  **Everything** (the full Console / Network / Dashboard, one tap away).
  Details open by tapping a row (the Inspector can no longer cold-open on
  "NOTHING SELECTED"), a labeled **Done** closes the viewer, Pause/Resume moved
  into the ⋯ menu as labeled actions, and the FAB badge / header / settings
  tile now all show the same number: open problems.

## 1.5.0

### Changed

- **UX P0 (from the usability audit): safer, clearer, honest.** One-tap
  "clear all" is gone — clearing now lives behind a confirm sheet ("Start a new
  session") that offers **Copy report first** and an **Undo** snackbar that
  restores everything. Every copy action shows the same confirmation
  ("Copied — paste it into your bug report"), including the previously silent
  Inspector Request/Response copy; exporting an empty session now says
  "Nothing captured yet" instead of copying an empty report. The Dashboard's
  AVG LATENCY card now shows the actual number (it previously rendered the
  literal text "ms"). New internals: a single-issue plain-language bug-report
  formatter (first wiring of `LayerXBlameEngine` into the product) and
  `LayerXLogStore.openProblemCount` as the one source of truth for problem
  badges.

## 1.4.2

### Changed

- **The debugger is now debug/profile-only by default.** When `environment` is
  not set explicitly, it auto-selects by build mode: `LayerXEnvironment.prod` in
  release builds (viewer/FAB off, warnings+ only) and `LayerXEnvironment.dev`
  otherwise. Previously the default was always `dev`, so a release build with
  the default config would show the debug FAB to end users. The FAB/viewer can
  no longer leak into a production release unless you opt in. Setting
  `environment` explicitly still overrides the auto-selection, and debug/profile
  behavior is unchanged.

## 1.4.1

### Fixed

- **The debug FAB now appears on every app with zero `builder:` wiring.**
  Previously the floating debug button only showed when `LayerXDebugOverlay` was
  wired into `MaterialApp.builder` — which the setup CLI skips whenever the app
  already declares a `builder:` (nearly every GetX app), so the FAB was missing
  even though the debugger initialized. The package now inserts the FAB/edge
  triggers into the app's root `Overlay` at runtime (driven by the route
  observer, kept above routes on navigation), so it works out of the box.
  `LayerXDebugOverlay` still works for anyone who uses it, and the shared single
  overlay entry guarantees there is never a duplicate FAB. All overlay work is
  deferred and guarded so it never affects route logging or the host app.

## 1.4.0

### Added

- **Viewer overhaul (Phase 2).** The in-app log viewer gains: filter by
  **category** and by **level** in the Console, **pause / resume** of live logs
  from the header, a **per-row copy** action, and — in the Inspector — the log's
  **category** and **source `file:line`** plus a **collapsible stack trace**.
  Internal UI only; no API changes.

## 1.3.0

### Added

- **Unified capture (Phase 1).** The in-app logs now also collect Flutter
  framework/UI exceptions (build, layout, render, paint, overflow), uncaught
  Dart/async/platform/isolate errors, and `print` / `debugPrint` console output
  — all flowing through the existing pipeline. Every entry now carries a
  `LayerXLogCategory` (App Logs, Flutter Framework, UI Exceptions, Dart
  Exceptions, Network, API, Navigation, Lifecycle, Performance, Crash Logs,
  Debug Console, System Logs) and, when parseable, a source file and line.
  Console capture runs in debug/profile builds; release keeps errors-only with
  the viewer off. A reentrancy guard prevents the debugger's own console output
  from being re-captured. All changes are additive and backward-compatible; the
  existing viewer shows the new entries as normal logs (category filtering is
  Phase 2).

## 1.2.3

### Added

- **Self-healing setup — a bad edit can no longer reach your build.** The verify
  step now syntax-checks every file the CLI touched (via `dart format` as a
  parse gate). If an injection left a file that no longer parses, it is
  automatically rolled back from its `.bak` and setup tells you to wire that
  spot manually, instead of leaving a non-compiling app. This is a general
  backstop for the regex-based source edits, so future edge cases fail safe.

## 1.2.2

### Fixed

- **Setup no longer crashes on Windows during the verify step.** `dart format`
  and `flutter analyze` were launched with `Process.run` without a shell; on
  Windows those tools are `.bat` shims, so the run threw an unhandled
  `ProcessException` ("The system cannot find the file specified") and aborted
  setup right at the end. Both commands now run with `runInShell: true` and are
  wrapped so a launch failure degrades to a warning instead of crashing.
- **Setup no longer injects a duplicate `builder:` into `MaterialApp` /
  `GetMaterialApp`.** When the app already declared its own `builder:` (or
  `navigatorObservers:`), the CLI still added a second one — a duplicate named
  argument that fails to compile. Each parameter is now injected only when the
  app doesn't already declare it at the top level of the constructor. When an
  existing `builder:` is found, it is left untouched and the CLI prints how to
  wrap its child with `LayerXDebugOverlay` manually.

## 1.2.1

### Fixed

- **Setup no longer produces invalid Dart when binding a class-level Dio
  field.** The auto-setup CLI used to append a separate
  `dio.interceptors.add(LayerXDioInterceptor());` statement after the matched
  `Dio(...)` initializer. That is only valid inside a function/constructor body;
  when the client is a plain field — e.g. `static final Dio _dio = Dio();` — the
  statement landed in the class body, where bare statements are illegal,
  triggering parser errors (`missing_method_parameters`, `expected_class_member`,
  …). The interceptor is now attached with a cascade on the constructor itself
  (`Dio()..interceptors.add(LayerXDioInterceptor())`), which is valid both in a
  field initializer and inside a function body.

## 1.2.0

### Changed

- **Brand-new "Neo Terminal" viewer UI.** The in-app debugger was fully
  restyled: a pure-black devtools console with a neon-green/cyan accent and
  monospace-forward type, a terminal command-bar header with a live log count
  and a blinking cursor, an animated bottom nav whose indicator slides to the
  active destination, fade-through page transitions, and staggered entrance
  animations on every list. Audited for zero overflow down to a 320px-wide
  screen (covered by a new widget test that taps through every destination,
  including mid-transition). Fixes a latent crash where issue/problem rows with
  a colored left rail threw `A borderRadius can only be given on borders with
  uniform colors` when painted.

### Added

- **`LayerXHttpClient` — generic capture for apps with their own HTTP client.**
  A transparent `http.BaseClient` decorator that wraps **any** inner client
  (a custom `IOClient`, a `RetryClient`, or the default `http.Client()`) and
  logs every request/response/error with no per-call setup. Apps that route all
  traffic through a single client — for example a `layerx_generator`-generated
  `HttpsCalls` service — now get full API capture by changing one line:
  `IOClient(...)` → `LayerXHttpClient(IOClient(...))`. Multipart requests are
  captured too, the request is never altered, and the caller always receives an
  intact response.
- **Auto-setup now wires API capture for you.** `dart run layerx_debugger:setup`
  detects the app's HTTP service and wraps its underlying `IOClient`/`http.Client`
  with `LayerXHttpClient` in a single robust edit (paren-balanced, type-widened,
  idempotent), instead of the previous fragile per-call-site rewrite that failed
  on large generated clients. This is why in-app API logs could be missing even
  when the console showed them — the capture hook was never applied; now it is.

## 1.1.0

### Added

- **Redesigned in-app debugger UI** — A completely new bottom-navigation experience
  with four destinations: **Dashboard** (session health score, live metric cards,
  latency sparkline, recent issues), **Network** (request rows with method/status/
  latency and `All / Errors / Slow / Δ Changed` filters), **Console** (all-source
  timeline with source filters + search), and **Inspector** (overview, response,
  request, and trace tabs, schema-diff and suggested-fix). Cyan + white brand accent.
- **Floating button visibility control** — The FAB and edge-swipe trigger now hide
  automatically while the debugger is open and restore on exit, preventing duplicate
  buttons and overlay conflicts.
- **Automatic frame-drop (jank) capture** — `LayerXFrameMonitor` records slow frames
  as performance warnings (rate-limited), installed automatically when performance
  logging is enabled.
- **Smarter API response handling** — A `2xx` response whose `Content-Type` claims
  JSON but whose body fails to parse is now flagged as a contract violation
  ("Unexpected response structure") instead of passing silently as success.
- **`LayerXNetworkLogger.recordParsingError(...)`** — A helper to report client-side
  model-mapping / deserialization failures so they surface as warnings with the
  offending response body.
- **Opt-in Dio integration** — `LayerXDioInterceptor`, available via
  `package:layerx_debugger/dio.dart`, forwards Dio responses and errors to LayerX.

### Changed

- **Rebuilt setup CLI** — Content-based detection of the logger/HTTP services
  (renamed classes are still found), idempotent marker-block injection, automatic
  Dio interceptor wiring, a guided snippet fallback for unrecognized HTTP wrappers,
  graceful skip when no HTTP service exists, a clear abort when no logger exists, and
  a post-run `dart format` + `flutter analyze` report. The injected dependency
  version is now resolved from the package itself.

### Removed

- Legacy internal viewer screens (`LxLogListScreen`, `LxLogDetailScreen`) and their
  now-unused part widgets, superseded by the new shell.

---

## 1.0.6

### Added

- **Auto-Setup CLI & Automatic Bindings** — Created a fully automated `dart run layerx_debugger:setup` command to seamlessly inject setup parameters, wrap `main.dart`, integrate overlay, and dynamically bind Logger and HTTP service configurations.
- **Idempotent CLI Steps** — Steps are verified to be fully idempotent, preventing redundant code modifications.
- **Constructor Injection Precision** — Added robust parsing to safely patch Logger constructors and target classes without creating stray formatting or trailing comma syntax issues.

---

## 1.0.5

### Added

- **Premium Dark UI Redesign** — Completely redesigned the in-app log viewer from scratch with a premium, high-end dark theme.
  - Added new central `LxTheme` design-token system for colors, typography, glowing overlays, cards, and animated indicators.
  - Redesigned `LxLogListScreen` with dark glass layout, live pulse dot, inline stats bar, custom clear confirmation dialog, and terminal-inspired empty state.
  - Redesigned `LxLogDetailScreen` with dark terminal aesthetics, custom syntax highlighted JSON viewer, dark schema diff tables, and custom level-based accent glow cards.
  - Updated widgets (`LxFabTrigger`, `LxEdgeTrigger`, `LxFilterBar`, `LxLogTile`, `LxSourceChip`, `LxDetailCard`, `LxSolutionCard`, `LxJourneyTimeline`) to align with the premium dark theme and utilize glowing accents.
  - Fixed navigator context crash by implementing a robust element tree traversal engine (`LayerXDebugger.findNavigator(context)`) to automatically locate the active `NavigatorState` when the context is above the Navigator (e.g. from `MaterialApp.builder` or nested contexts).

---

## 1.0.4

### Fixed

- **Architecture detection now uses folder structure, not class names** — the
  `dart run layerx_debugger:setup` CLI previously scanned source files for
  `LayerXController` / `LayerXService` class names, which caused false negatives
  on valid LayerX projects. Detection now checks for the canonical LayerX folder
  layout under `lib/app/`:
  - `lib/app/mvvm/` — required
  - `lib/app/services/` — required
  - `lib/app/config/`, `lib/app/repository/`, `lib/app/widgets/`,
    `lib/app/customWidgets/` — optional (shown as ✓ if present, never required)

  A project is considered LayerX-compliant if `lib/app/` exists and at least
  one of the required folders is present. The abort message now also shows the
  exact expected folder structure to make the requirement clear.

---

## 1.0.3


### Added

- **LayerX Architecture detector in `dart run layerx_debugger:setup`** — the CLI now
  scans `lib/` for LayerX signals (`LayerXController`, `LayerXService`, `LayerXDebugMixin`,
  `GetMaterialApp`, `GetPage`) before running any setup steps. If no LayerX pattern is
  detected, setup is aborted with a clear, color-coded terminal message directing the user
  to adopt the LayerX Architecture first using
  [`layerx_generator`](https://pub.dev/packages/layerx_generator). Nothing is written to
  the project in this case — the tool is fully non-destructive on abort.

---

## 1.0.2


### Fixed

- **Navigator context crash** — `LxFabTrigger`, `LxEdgeTrigger` and `LayerXDebugger.openViewer`
  now use `Navigator.of(context, rootNavigator: true)` (and `showModalBottomSheet` uses
  `useRootNavigator: true`). Previously, tapping the floating 🐛 button or swiping the
  edge trigger threw *"Navigator operation requested with a context that does not include a
  Navigator"* because `LayerXDebugOverlay` is placed inside `MaterialApp`'s `builder:`
  callback — which sits **above** the `Navigator` in the widget tree. Using the root
  navigator bypasses this scope and resolves the crash.

---

## 1.0.1


### Added

- **`dart run layerx_debugger:setup` CLI** — one command auto-configures LayerX Debugger in any
  Flutter project: injects the dependency into `pubspec.yaml`, runs `flutter pub get`, wraps
  `main()` with `LayerXDebugger.runZonedGuarded` + `initialize()`, and injects
  `LayerXDebugOverlay` builder + `navigatorObservers` into `MaterialApp` /
  `GetMaterialApp`. Original files are backed up as `.bak`. Fully idempotent — safe to
  re-run multiple times. An optional project path argument is also supported:
  `dart run layerx_debugger:setup /path/to/project`.

---

## 1.0.0


🎉 **First release — in-app debugging for Flutter.**

A complete, zero-boilerplate debugging ecosystem that lives *inside* your running app:
one `LayerXDebugger.initialize()` call wires up logging, network capture, crash handling,
GetX integration and a full in-app log viewer.

### Added

- **In-app viewer** — draggable floating button, edge-swipe and `LayerXDebugSettingsButton`,
  plus `LayerXDebugger.openViewer(context)` to open it from any button. Searchable, filterable,
  color-coded log list with a session-health banner and a rich detail screen.
- **"Who owns this bug?" blame engine** — attributes each failure to app / backend / network
  with a QA-ready note, a suggested fix, and a step-by-step journey timeline.
- **API response diffing** — detects when a backend changes its JSON shape and renders a
  field-level diff (added / removed / type-changed / value-changed).
- **Logging** — `LayerXLog.d/i/w/e/s` (+ `v`, `wtf`), `LayerXLog.screen()`, `LayerXLog.action()`,
  structured `log(...)`, `apiError(...)`, and `Object.logD()/logE()/...` extensions. Colored,
  emoji-tagged console output with boxed `┌─ │ └` API blocks; auto-disabled in production.
- **One-call setup & detection** — applies config, installs crash handling, and (in a
  LayerX/GetX app) auto-registers the LayerX GetX services with duplicate-prevention and a
  double-initialization guard. Best-effort architecture detection activates modules
  incrementally and prints a status banner.
- **Auto-injected GetX services** — `LayerXLoggerService`, `LayerXDebugService`,
  `LayerXCrashService`, `LayerXNetworkService`, `LayerXPerformanceService`,
  `LayerXRouteService` (via `LayerXBindings`).
- **Networking** — `http` is the primary integration via `LayerXHttp`
  (`get/post/put/patch/delete`) and the shared `LayerXNetworkLogger`; sensitive fields are
  masked (`********`). Dio is supported optionally via a documented interceptor recipe —
  **no forced `dio` dependency**.
- **Crash handling** — global `FlutterError`, `PlatformDispatcher` and zone capture, with an
  `onCrash` hook for optional Firebase Crashlytics / Sentry forwarding.
- **GetX** — `LayerXController`, `LayerXService`, `LayerXDebugMixin`, and
  `LayerXRouteMiddleware`; `LayerXRouteObserver` for `navigatorObservers`.
- **Performance & widgets** — `LayerXProfiler.start/end/measure(name, fn)` and the
  `LayerXDebugWidget(tag:)` rebuild counter.
- **Configuration** — `LayerXDebugConfig` with per-feature toggles, sensitive-key masking,
  `LayerXEnvironment` (dev/staging/prod) verbosity, `autoInject` and `isLayerXArchitecture`.
