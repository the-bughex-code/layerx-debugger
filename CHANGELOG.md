# Changelog

All notable changes to **layerx_debugger** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
