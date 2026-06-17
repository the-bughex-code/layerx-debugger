# Changelog

All notable changes to `layerx_debugger` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

Initial release.

### Added

- **Logging** — `LayerXLog` facade with `d`, `i`, `w`, `e`, `s` (success), `v`, `wtf`,
  a structured `log(...)` API, and an `apiError(...)` shorthand.
- **Pretty console output** — box-style (`┌─ │ └`) rendering with ANSI colors
  (blue/green/yellow/red/grey), automatically disabled in release/production.
- **One-call setup & detection** — `LayerXDebugger.initialize({config})` applies config,
  installs crash handling, and (in a LayerX/GetX app) auto-registers the LayerX GetX
  services with duplicate-prevention and a double-initialization guard. Best-effort
  architecture detection prints a banner and activates modules incrementally.
- **Auto-injected GetX services** — `LayerXLoggerService`, `LayerXDebugService`,
  `LayerXCrashService`, `LayerXNetworkService`, `LayerXPerformanceService`,
  `LayerXRouteService` (via `LayerXBindings`).
- **Configuration** — `LayerXDebugConfig` toggles for API, route, crash, GetX, performance
  and widget logs; sensitive-key masking; `LayerXEnvironment` (dev/staging/prod) verbosity;
  `autoInject` and `isLayerXArchitecture` controls.
- **Network capture** — `http` is the primary integration via `LayerXHttp`
  (`get/post/put/patch/delete`) and the shared `LayerXNetworkLogger`. Dio is supported
  optionally via a documented interceptor recipe — **no forced dio dependency**. Sensitive
  fields are masked (`********`).
- **Navigation** — `LayerXRouteObserver` (Navigator) and `LayerXRouteMiddleware` (GetX).
- **Crash handling** — global `FlutterError`, `PlatformDispatcher` and zone capture, with
  an `onCrash` hook for optional Firebase Crashlytics / Sentry forwarding.
- **GetX** — `LayerXController`, `LayerXService` and `LayerXDebugMixin` with lifecycle logs.
- **Screen & action logging** — `LayerXLog.screen()` and `LayerXLog.action()`.
- **Performance** — `LayerXProfiler` with `start/end/measure(name, fn)`.
- **Widgets** — `LayerXDebugWidget` rebuild counter and the in-app `LayerXDebugOverlay`
  log viewer (draggable FAB, edge swipe, searchable list and rich detail screen with
  blame/solution analysis, journey timeline and API response diffing).
