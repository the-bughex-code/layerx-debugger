# layerx_debugger Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans (inline) to implement this plan
> phase-by-phase. Steps use checkbox (`- [ ]`) syntax. Ported files are mechanical
> renames of FesoRide `lib/app/debug_logger/*` — port faithfully, swap `Lx`→`LayerX`
> on public types, fix imports, generalize the hard-coded package name.

**Goal:** Extract FesoRide's debugger into a publishable, generic `layerx_debugger` Flutter package.

**Architecture:** `LayerX*` public facade over ported internals; single barrel export
`package:layerx_debugger/layerx_debugger.dart`; core decoupled from GetX (uses Navigator),
GetX shipped as a dependency for the GetX integration + viewer nav.

**Tech Stack:** Flutter 3.27+, Dart 3.6+, `logger`, `intl`, `get`, `dio`, `http`.

**Verification gate (run after every phase):**
`cd /Users/umairhashmi/StudioProjects/layerxdebugger && dart format . && flutter analyze && flutter test`
Final gate also: `dart pub publish --dry-run`. Iterate until zero warnings/errors.

---

## Phase 0 — Package scaffold
**Files:** `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `CHANGELOG.md`, `.gitignore`,
`lib/layerx_debugger.dart` (stub barrel), remove app-only `web/` and stray `lib/main.dart`/`test/widget_test.dart`.
- [ ] Rewrite `pubspec.yaml`: name `layerx_debugger`, description (60–180 chars), version 1.0.0,
      BSD-3 metadata, repository/homepage/issue_tracker, SDK `>=3.6.0 <4.0.0` & flutter `>=3.27.0`,
      deps `logger/intl/get/dio/http`, dev `flutter_test/flutter_lints`, topics, drop `publish_to`.
- [ ] Strict `analysis_options.yaml` (`flutter_lints` + `public_member_api_docs`, `lines_longer_than_80_chars: false`, etc.).
- [ ] `LICENSE` (BSD-3-Clause, "The BugHex", 2026). `CHANGELOG.md` (## 1.0.0 initial).
- [ ] Stub `lib/layerx_debugger.dart` with library doc comment.
- [ ] Delete default `web/`, `lib/main.dart`, `test/widget_test.dart`.
- [ ] Gate: `flutter pub get` + `flutter analyze` clean.

## Phase 1 — Models (`lib/src/models/`)
**Files:** `layerx_log_level.dart` (+`success`), `layerx_log_source.dart`, `layerx_journey_step.dart`,
`layerx_schema_change.dart`, `layerx_log_entry.dart`. **Test:** `test/models/log_level_test.dart`.
- [ ] Port `LxLogLevel`→`LayerXLogLevel`, add `success` (green `0xFF43A047`, emoji ✅, between info & warning).
- [ ] Port source/journey/schema/entry → `LayerX*`; entry renamed `LayerXLogEntry`; doc every public member.
- [ ] Test: level color/label/emoji incl. `success`; entry `copyWith`; journey `toJson/fromJson` round-trip.
- [ ] Gate.

## Phase 2 — Utils & engines (`lib/src/utils/`)
**Files:** `layerx_duplicate_guard.dart`, `layerx_source_detector.dart`, `layerx_solution_engine.dart`,
`layerx_blame_engine.dart`, `layerx_json_diff.dart`, `layerx_log_store.dart`.
**Tests:** one per engine under `test/utils/`.
- [ ] Port engines faithfully (rename types, fix imports). Move JSON-diff helpers out of store into `layerx_json_diff.dart` (DRY); store calls it.
- [ ] `LayerXLogStore`: gate writes on `LayerXDebugger.config.isStoreEnabled` instead of bare `kDebugMode`; add `maxStoredLogs` trim.
- [ ] Tests: dedup window; source detector (5xx/4xx/network/app/unknown); solution engine sample matches; json-diff added/removed/typeChanged/valueChanged; store add/dedup/update/clear/export string.
- [ ] Gate.

## Phase 3 — Logger (`lib/src/logger/`)
**Files:** `layerx_logger_service.dart`, `layerx_console_printer.dart`, `layerx_log.dart`, `layerx_log_output.dart`.
**Test:** `test/logger/layerx_log_test.dart`.
- [ ] Port `LoggerService`→`LayerXLoggerService` (internal); printer respects env/colors.
- [ ] `LayerXConsolePrinter`: box `┌─ │ └` builder + ANSI color map (blue/green/yellow/red/grey), `useColors` flag, helper `box(title, lines)`.
- [ ] `LayerXLog` facade: `d/i/w/e/s/v/wtf` + `log(...)` + `apiError(...)`. `s()` → success level (green). Map success→Level.info for `logger` pkg, tag as success in store.
- [ ] `LayerXLogOutput`: port; generalize `_parseStackTrace` (skip `dart:`/`package:flutter`/`package:logger`/`package:layerx_debugger` + optional `config.packageName`; take first remaining frame).
- [ ] Test: `LayerXLog.s/d/e` don't throw; console printer emits box lines; success maps correctly.
- [ ] Gate.

## Phase 4 — Core: config, environment, crash, initialize (`lib/src/core/`, `lib/src/crash/`, `lib/src/network/layerx_masker.dart`)
**Files:** `layerx_environment.dart`, `layerx_debug_config.dart`, `crash/layerx_crash_handler.dart`,
`core/layerx_debugger.dart`, `network/layerx_masker.dart`. **Tests:** config/env/masker.
- [ ] `LayerXEnvironment {dev, staging, prod}` + `minLevel`/`useColors`/`viewerEnabled` getters.
- [ ] `LayerXDebugConfig`: `enableApiLogs/enableRouteLogs/enableCrashLogs/enableGetXLogs/enablePerformanceLogs/enableWidgetLogs`,
      `maskKeys`, `environment`, `appName`, `packageName?`, viewer toggles (`enableFloatingButton/enableEdgeSwipe/enableSettingsWidget/edgeSwipeZone`),
      `useColors?`, `maxStoredLogs`, `onCrash`. Sensible defaults; `const` constructor.
- [ ] `LayerXMasker.mask(dynamic, {keys})` recursive; default keys password/token/authorization/apikey/secret; `********`.
- [ ] `LayerXCrashHandler.install(config)` (port FlutterError + PlatformDispatcher hooks, route to network logger + `config.onCrash`); `runZonedGuarded(body, config)`.
- [ ] `LayerXDebugger`: `static config`, `initialize({config})` (set config, install crash handler, init logger), `runZonedGuarded(...)`, `routeObserver` getter, `dioInterceptor` getter, `overlay(child)` helper.
- [ ] Tests: config defaults; env gating; masker masks nested + arrays + case-insensitive; initialize twice is idempotent.
- [ ] Gate.

## Phase 5 — Network (`lib/src/network/`)
**Files:** `layerx_network_logger.dart`, `layerx_dio_interceptor.dart`, `layerx_http.dart`. **Tests:** dio + masking.
- [ ] `LayerXNetworkLogger.record(...)`: port `LxHttpInterceptor.record/recordFlutterError/recordUncaughtError`; apply masker; console box via printer; gate on `config.enableApiLogs`.
- [ ] `LayerXDioInterceptor extends Interceptor`: onRequest/onResponse/onError → build masked entries + durations (store request time in `options.extra`).
- [ ] `LayerXHttp`: static `get/post/put/delete` over `package:http`, time round-trip, forward to network logger.
- [ ] Tests: dio interceptor produces store entry w/ masked Authorization; http wrapper logs (use a mock client).
- [ ] Gate.

## Phase 6 — Navigation (`lib/src/navigation/`)
**Files:** `layerx_route_observer.dart`, `layerx_route_middleware.dart`. **Test:** observer.
- [ ] Port `LxNavigationObserver`→`LayerXRouteObserver`; ignore own viewer screens; gate on `config.enableRouteLogs`.
- [ ] `LayerXRouteMiddleware extends GetMiddleware`: log redirect/onPageCalled route names.
- [ ] Test: pushing a named route adds an info log with route name.
- [ ] Gate.

## Phase 7 — GetX (`lib/src/getx/`)
**Files:** `layerx_controller.dart`, `layerx_service.dart`, `layerx_debug_mixin.dart`. **Test:** mixin lifecycle.
- [ ] `LayerXDebugMixin on GetxController`: log `onInit/onReady/onClose` with runtimeType; gate on `config.enableGetXLogs`.
- [ ] `LayerXController extends GetxController with LayerXDebugMixin`; `LayerXService extends GetxService` (+ same logging).
- [ ] Test: a `LayerXController` put/delete in GetX emits init+close logs.
- [ ] Gate.

## Phase 8 — Profiler + widgets + viewer (`lib/src/widgets/`, `lib/src/utils` profiler)
**Files:** `core/layerx_profiler.dart`, `widgets/layerx_debug_widget.dart`, `widgets/layerx_debug_overlay.dart`,
`widgets/lx_fab_trigger.dart`, `widgets/lx_edge_trigger.dart`, `widgets/screens/lx_log_list_screen.dart`,
`widgets/screens/lx_log_detail_screen.dart`, `widgets/parts/*`. **Tests:** profiler, rebuild widget, fab badge, log tile.
- [ ] `LayerXProfiler`: `start(tag)/end(tag)` (logs ms), `measure<T>(fn,{tag})`, `measureSync<T>`.
- [ ] `LayerXDebugWidget`: counts builds via a label, logs "<label> rebuilt N times"; gate on `config.enableWidgetLogs`.
- [ ] Port FAB/edge/screens/parts → internal; replace `Get.to(...)` with `Navigator.of(context).push(MaterialPageRoute(...))` so core needs no Get; rename to internal `Lx*` files (unexported) or `LayerX*` if public.
- [ ] `LayerXDebugOverlay(child)`: port `LxDebugEntry`; respects config viewer toggles + env.
- [ ] Tests: profiler measures > 0; `LayerXDebugWidget` logs increasing count on rebuild; FAB badge shows error count; log tile renders message.
- [ ] Gate.

## Phase 9 — Extensions + barrel (`lib/src/extensions/`, `lib/layerx_debugger.dart`)
**Files:** `extensions/layerx_log_extensions.dart`, barrel. **Test:** extension.
- [ ] `extension LayerXLogX on Object { void logD()/logI()/logW()/logE()/logS(); }`.
- [ ] Barrel exports every public API (`LayerX*`), hides internal `Lx*`. Library doc comment with quick-start.
- [ ] Test: `"x".logE()` doesn't throw and records.
- [ ] Gate.

## Phase 10 — Example app (`example/`)
**Files:** `example/pubspec.yaml`, `example/lib/main.dart`, `example/README.md`, `example/analysis_options.yaml`.
- [ ] GetX app: `LayerXDebugger.initialize(config:)` in `runZonedGuarded`; `GetMaterialApp` with `LayerXRouteObserver` + `LayerXDebugOverlay` builder; buttons exercising log levels, Dio call, http call, profiler, `LayerXDebugWidget`, a `LayerXController`, a crash trigger.
- [ ] Gate: `cd example && flutter pub get && flutter analyze`.

## Phase 11 — Docs + CI
**Files:** `README.md`, `.github/workflows/ci.yaml`, `.github/workflows/publish.yaml`, `doc/` screenshot placeholders.
- [ ] README: badges, Installation, Quick Start, Dio, GetX, Route Debugging, Crash Handling (incl. Crashlytics/Sentry via `onCrash`), Performance, Widget Monitoring, Console Output sample, full example, screenshot/GIF placeholders, License.
- [ ] CI workflow (format check, `flutter analyze`, `flutter test` on stable). Publish workflow (dry-run on PR; `flutter pub publish` on tag via OIDC placeholder).
- [ ] Gate.

## Phase 12 — Final hardening
- [ ] `dart format .` → no changes. `flutter analyze` → "No issues found!". `flutter test` → all pass.
- [ ] `dart pub publish --dry-run` → "has 0 warnings". Fix any (description length, license recognized, example present, etc.).
- [ ] Verify pub-score factors: docs on all public members, example exists, deps current, platforms declared.

## Self-review notes
- Spec coverage: logger(P3), console box(P3), Dio(P5), http(P5), masking(P4/P5), GetX(P7), routes(P6),
  crash+zoned(P4), widget rebuild(P8), profiler(P8), auto-init(P4), environment(P4), config(P4),
  single import(P9), docs(P11), pub quality(P12), viewer(P8). All mapped.
- Type consistency: `LayerXLogEntry` (model) vs `LayerXLog` (facade) kept distinct throughout.
- Ported screens stay internal (`Lx*` filenames, unexported) to limit public surface + doc burden.
