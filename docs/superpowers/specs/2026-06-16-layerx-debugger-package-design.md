# layerx_debugger — Design Spec

**Date:** 2026-06-16
**Status:** Approved
**Author:** The BugHex
**Source project:** FesoRide (`/Users/umairhashmi/StudioProjects/FesoRide-APP`, `lib/app/debug_logger/` + `lib/app/services/logger_service.dart`)
**Target package:** `/Users/umairhashmi/StudioProjects/layerxdebugger`

## 1. Goal

Extract the FesoRide debugger/logger system into a generic, reusable, publishable Flutter
package named `layerx_debugger` that works out-of-the-box in any GetX + LayerX project and
is also usable (core features) in non-GetX apps. Target: clean `dart analyze`, passing tests,
clean `dart pub publish --dry-run`, and a high pub.dev score (≈160 points).

A developer installs the package, calls `await LayerXDebugger.initialize()`, and gets the same
behaviour as FesoRide with no manual boilerplate.

## 2. Approved decisions

1. **Scope:** Full port of the FesoRide system (console logging, HTTP capture, crash hooks,
   navigation, AND the in-app visual viewer: FAB/edge triggers, log list + detail screens,
   blame engine, solution engine, journey timeline, schema-diffing) PLUS new spec features
   (Dio interceptor, `LayerXHttp`, GetX controller/service/mixin/middleware, widget-rebuild
   tracking, profiler, environments, masking, unified init).
2. **GetX coupling (both):** `get` ships as a real dependency so GetX integration and the
   viewer's navigation work out-of-the-box; the core (logger/network/crash/profiler/widgets)
   is decoupled — it imports only Flutter + uses `Navigator`, never `Get` — so it still works
   in non-GetX apps. `Get` is imported only under `src/getx/` and the viewer overlay's
   navigation shim.
3. **Naming:** Public API is `LayerX*` only. Internal helpers may keep `Lx`-prefixed names but
   are NOT exported.
4. **Publishing identity:** Author "The BugHex", license BSD-3-Clause, repository/homepage
   `https://github.com/the-bughex-code/layerx_debugger` (placeholder; correct later).

## 3. Environment

- Flutter 3.44.1 / Dart 3.12.1 on dev machine.
- pubspec constraints: `sdk: '>=3.6.0 <4.0.0'`, `flutter: '>=3.27.0'` (uses `Color.withValues`,
  Dart 3 records/patterns). Bump if the analyzer flags lower-bound API availability.
- Target is currently a default Flutter **application** template (has android/ios/web/etc.,
  `publish_to: 'none'`, name `layerxdebugger`). It must be converted to a publishable
  **package** named `layerx_debugger` (remove app-only platform folders + web/, drop
  `publish_to`, restructure `lib/`).

## 4. Naming map (FesoRide → package public API)

| FesoRide (`Lx*`) | Public API | Notes |
|---|---|---|
| `LxLogger` | `LayerXLog` | static `d/i/w/e/s` (+ `v/wtf/fatal`); `s()` = success (green) — NEW level |
| `LoggerService` | `LayerXLoggerService` *(internal)* | keeps `logger` package pretty printer |
| `LxLog` (entry) | `LayerXLogEntry` | renamed to avoid clash with `LayerXLog` logger |
| `LxLogLevel` | `LayerXLogLevel` | adds `success` |
| `LxLogSource` | `LayerXLogSource` | |
| `LxJourneyStep` | `LayerXJourneyStep` | |
| `LxSchemaChange` / `LxSchemaDiffType` | `LayerXSchemaChange` / `LayerXSchemaDiffType` | |
| `LxLogStore` | `LayerXLogStore` | in-memory ValueNotifier + JSON diff + export |
| `LxDuplicateGuard` | internal | |
| `LxSourceDetector` | internal | generalized |
| `LxSolutionEngine` | internal (`LayerXSolutionEngine` exposed read-only) | ~20 regex rules |
| `LxBlameEngine` / `LxBlameInfo` | `LayerXBlameEngine` / `LayerXBlameInfo` | |
| `LxHttpInterceptor.record` | `LayerXNetworkLogger.record` | shared capture core |
| — | `LayerXDioInterceptor extends Interceptor` | NEW (Dio) |
| — | `LayerXHttp` | NEW (`get/post/put/delete` over package:http) |
| `LxNavigationObserver` | `LayerXRouteObserver extends NavigatorObserver` | |
| — | `LayerXRouteMiddleware extends GetMiddleware` | NEW (GetX routes) |
| `LxLoggerConfig.init` | `LayerXDebugger.initialize(config:)` + `LayerXDebugConfig` | unified entry |
| (FlutterError/PlatformDispatcher hooks) | `LayerXCrashHandler` | + `runZonedGuarded` helper + `onCrash` hook |
| `LxDebugEntry` | `LayerXDebugOverlay` | viewer host (FAB + edge) |
| `LxFabTrigger` / `LxEdgeTrigger` | internal widgets | nav via `Navigator` (Get optional) |
| `LxLogListScreen` / `LxLogDetailScreen` | internal screens | ported faithfully, renamed |
| viewer widgets (tile, filter, timeline, cards, source chip, settings button) | internal | |
| — | `LayerXController` / `LayerXService` / `LayerXDebugMixin` | NEW (GetX lifecycle) |
| — | `LayerXDebugWidget` | NEW (rebuild counter) |
| — | `LayerXProfiler` | NEW (`start/end/measure`) |
| — | `LayerXEnvironment {dev, staging, prod}` | NEW |
| — | `LayerXMasker` | NEW (sensitive-key masking) |
| — | `LayerXConsolePrinter` | NEW (`┌─ │ └` box for API logs, ANSI colors) |

## 5. Directory layout

```
lib/layerx_debugger.dart            # single barrel export — the only import consumers need
lib/src/
  core/
    layerx_debugger.dart            # LayerXDebugger.initialize() + runZonedGuarded helper
    layerx_debug_config.dart        # LayerXDebugConfig (enable* flags, maskKeys, environment, viewer toggles, onCrash)
    layerx_environment.dart         # LayerXEnvironment enum + verbosity rules
  logger/
    layerx_log.dart                 # LayerXLog facade (d/i/w/e/s/v/wtf, log(), apiError())
    layerx_logger_service.dart      # internal: logger pkg + CustomPrinter
    layerx_console_printer.dart     # box-style ANSI formatter for network logs
    layerx_log_output.dart          # logger LogOutput → LayerXLogStore (generalized stack parsing)
  network/
    layerx_network_logger.dart      # shared record() core (from LxHttpInterceptor)
    layerx_dio_interceptor.dart     # LayerXDioInterceptor extends Interceptor
    layerx_http.dart                # LayerXHttp.get/post/put/delete wrappers
    layerx_masker.dart              # LayerXMasker
  navigation/
    layerx_route_observer.dart      # LayerXRouteObserver
    layerx_route_middleware.dart    # LayerXRouteMiddleware (GetX)
  crash/
    layerx_crash_handler.dart       # FlutterError + PlatformDispatcher + runZonedGuarded + onCrash
  getx/
    layerx_controller.dart          # LayerXController extends GetxController (lifecycle logs)
    layerx_service.dart             # LayerXService extends GetxService
    layerx_debug_mixin.dart         # LayerXDebugMixin on GetxController
  widgets/
    layerx_debug_widget.dart        # LayerXDebugWidget rebuild counter
    layerx_debug_overlay.dart       # LayerXDebugOverlay (host for FAB + edge)
    lx_fab_trigger.dart             # internal
    lx_edge_trigger.dart            # internal
    screens/lx_log_list_screen.dart, screens/lx_log_detail_screen.dart   # internal
    parts/ (lx_log_tile, lx_filter_bar, lx_journey_timeline, lx_solution_card,
            lx_detail_card, lx_source_chip, lx_debug_settings_button)      # internal
  models/
    layerx_log_entry.dart · layerx_log_level.dart · layerx_log_source.dart
    layerx_journey_step.dart · layerx_schema_change.dart
  extensions/
    layerx_log_extensions.dart      # e.g. Object.logD()/logE(); String shortcuts
  utils/
    layerx_log_store.dart · layerx_duplicate_guard.dart · layerx_source_detector.dart
    layerx_solution_engine.dart · layerx_blame_engine.dart · layerx_json_diff.dart
example/                            # GetX demo app exercising every feature
test/                              # unit + widget tests
.github/workflows/ci.yaml          # format + analyze + test
.github/workflows/publish.yaml     # pub.dev publish on tag (dry-run on PR)
README.md · CHANGELOG.md · LICENSE · analysis_options.yaml · pubspec.yaml
```

## 6. Dependencies

Runtime: `logger ^2.5`, `intl ^0.20`, `get ^4.7`, `dio ^5`, `http ^1` — all pure-Dart /
all-platform (no pub-score platform penalty). **No** firebase/sentry deps: Crashlytics/Sentry
are integrated via the `config.onCrash(error, stack, {fatal})` callback so the package works
standalone. Optional integration snippets in README.

Dev: `flutter_test`, `flutter_lints` (latest), strict `analysis_options.yaml` with
`public_member_api_docs: true` to drive the docs pub metric (all public members documented).

## 7. Feature behaviour

- **`LayerXDebugger.initialize({LayerXDebugConfig config})`**: stores config; installs
  `LayerXCrashHandler`; wires the logger output into `LayerXLogStore`; prepares shared
  `LayerXRouteObserver`/`LayerXDioInterceptor` instances accessible via getters. Also
  `LayerXDebugger.runZonedGuarded(() => runApp(...))`.
- **Console box** (`LayerXConsolePrinter`): renders `┌─ API REQUEST … └` blocks with ANSI
  colors — blue=info, green=success, yellow=warning, red=error, grey=debug. Auto-off in
  release/prod or when `config.useColors == false`.
- **Masking** (`LayerXMasker`): recursively replaces values of `password/token/authorization/
  apiKey/secret` + `config.maskKeys` (case-insensitive) with `********`; applied to headers
  and bodies in both interceptors.
- **Environment** (`LayerXEnvironment`): `prod` suppresses verbose/debug + colors + viewer;
  `staging` keeps info+; `dev` keeps all. Replaces blanket `kDebugMode` gates with
  env/config-aware checks (defaults remain debug-safe).
- **Generalize hard-coded `package:fasoride_project`** in `_parseStackTrace` → package-agnostic
  heuristic (skip dart:/flutter/logger/own-package frames; take first app frame) + optional
  `config.packageName` hint.
- **GetX**: `LayerXController`/`LayerXService` auto-log `onInit/onReady/onClose`;
  `LayerXDebugMixin` adds the same to existing controllers; `LayerXRouteMiddleware` logs GetX
  route changes (redirect/onPageCalled).
- **Profiler** (`LayerXProfiler`): `start(tag)` / `end(tag)` (logs duration), `measure(fn)` /
  `measureSync(fn)`.
- **Widget rebuilds** (`LayerXDebugWidget(child:)`): counts builds, logs "Name rebuilt N times".

## 8. Quality gates & deliverables

- `flutter analyze` clean (zero warnings/infos), `dart format` clean.
- Unit tests: masker, source detector, solution engine, duplicate guard, json-diff, log store
  (add/dedup/update/export), profiler timing, config defaults, environment gating, log-level
  colors/labels.
- Widget tests: `LayerXDebugWidget` rebuild counting, FAB badge count, log tile rendering.
- README with: Installation, Quick Start, Dio, GetX, Route Debugging, Crash Handling,
  Performance, Widget Monitoring, full examples, screenshot/GIF placeholders.
- CHANGELOG (1.0.0), BSD-3 LICENSE (The BugHex), semantic version 1.0.0.
- GitHub Actions: CI (format/analyze/test) + publish workflow.
- Example app under `example/` exercising every feature (drives the "has example" metric).
- Iterate `flutter analyze` → `flutter test` → `dart pub publish --dry-run` until clean.

## 9. Out of scope

- FesoRide itself is NOT modified (deliverable is the package). A follow-up could migrate
  FesoRide to consume the package.
- No real pub.dev publish (no credentials); only `--dry-run` must pass.
- Crashlytics/Sentry are integration hooks only — not bundled.
