# Changelog

All notable changes to **layerx_debugger** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
