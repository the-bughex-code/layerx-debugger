# Unified Logging Capture — Phase 1 Design

**Date:** 2026-07-01
**Status:** Approved (design)
**Scope:** Capture layer only. The viewer-UI overhaul (filters, pause, collapse,
share) is **Phase 2** and gets its own spec.

## Context

LayerX already has a unified logging pipeline. The custom logger (`LayerXLog`),
the network loggers (`LayerXNetworkLogger` / `LayerXDioInterceptor` /
`LayerXHttpClient`), and the crash handler (`LayerXCrashHandler`) all converge
at a single ingestion point, `LayerXLogOutput.ingest()`, which builds a
`LayerXLogEntry` and stores it in `LayerXLogStore` (a `ValueNotifier`-backed,
500-entry ring buffer with deduplication). The Neo Terminal viewer renders that
store.

`FlutterError.onError`, `PlatformDispatcher.onError`, and `runZonedGuarded` are
**already** hooked by `LayerXCrashHandler` (gated by `config.enableCrashLogs`).
So widget/render/layout/paint/assertion/navigator/animation/gesture exceptions —
which all route through `FlutterError.onError` — are already captured when crash
logs are enabled and the app wraps `runZonedGuarded`.

### What is genuinely missing today

1. **`print()` / `debugPrint()` console output** is not captured anywhere. UI
   problems that Flutter writes to the console (e.g. `RenderFlex overflowed`
   banners, error dumps) never reach the in-app logs because they do not go
   through `LayerXLog`.
2. **No `category` facet.** Entries carry `level` (severity) and `source`
   (ownership: app/server/backend/network), but nothing groups them into the
   functional "sections" the product needs (Framework, UI Exceptions, Debug
   Console, Lifecycle, …).
3. **Isolate errors** are not captured.
4. **No source file / line** on entries (only a parsed screen/method symbol).

## Goals

- Capture Flutter framework console output and `print`/`debugPrint` into the
  in-app logs, in their own category.
- Add a `category` facet so every entry is grouped into a clear section.
- Classify framework vs UI vs Dart exceptions instead of dumping them all as
  generic errors.
- Capture isolate errors where the platform supports it.
- Record source file + line when available.
- Do all of this **without breaking the existing logger, model, store, or
  viewer**, and **without ever crashing the host app**.

## Non-goals (Phase 2)

Viewer changes — category/level filter UI, pause/resume, collapse/expand stack
traces, native share, per-row copy. Phase 1 only makes the new data available;
the existing viewer keeps working unchanged (new entries appear like any other).

## Decisions (from brainstorming)

- **Console capture depth:** broadest sensible — override `debugPrint` always,
  and hook zone `print` via the existing `runZonedGuarded`.
- **Build modes:** full capture in debug/profile; release keeps errors-only with
  the viewer off (unchanged `prod` behavior). Console capture and full
  categorization install only outside release.
- **Delivery:** two phases; this spec is Phase 1.

## Design

### Approach

Extend the existing pipeline. Every new capture source feeds the same
`LayerXLogOutput.ingest()` choke point; the only model change is one additive
facet plus two optional location fields. No parallel pipeline, no rewrite. This
degrades gracefully: the `debugPrint` override works even if an app never wraps
a zone; the zone `print` hook is an additive bonus.

### 1. `LayerXLogCategory` facet

New enum `lib/src/config/enums/layerx_log_category.dart` with the 12 buckets,
each exposing `label`, `color`, and `icon` (mirroring `LayerXLogLevel` /
`LayerXLogSource`, so the viewer can render it with no new plumbing):

| value          | label            | meaning                                            |
|----------------|------------------|----------------------------------------------------|
| `app`          | App Logs         | manual `LayerXLog.*` calls                          |
| `framework`    | Flutter Framework| non-exception framework diagnostics                |
| `uiException`  | UI Exceptions    | build / layout / render / paint / overflow         |
| `dartException`| Dart Exceptions  | uncaught async / platform / zone / isolate errors  |
| `network`      | Network          | transport / connectivity failures                  |
| `api`          | API              | HTTP request/response exchanges                    |
| `navigation`   | Navigation       | route changes                                      |
| `lifecycle`    | Lifecycle        | GetX controller/service lifecycle                  |
| `performance`  | Performance      | frame / jank / profiler                            |
| `crash`        | Crash Logs       | fatal errors                                       |
| `debugConsole` | Debug Console    | captured `print` / `debugPrint`                    |
| `system`       | System Logs      | LayerX internal (init banner, self-diagnostics)    |

**Model change:** add `final LayerXLogCategory category;` to `LayerXLogEntry` as
a **named parameter with a default** (`LayerXLogCategory.app`), so the existing
constructor, `copyWith`, and all current call sites keep compiling unchanged.
`copyWith` gains a `category` parameter. The enum is exported from
`layerx_debugger.dart`.

**Ingestion:** `LayerXLogOutput.ingest()` gains an optional
`LayerXLogCategory? category`. When null it is derived: `endpoint != null` →
`api`, otherwise `app`. Every producer passes its own category (crash handler →
`uiException`/`framework`/`dartException`/`crash`; route observer → `navigation`;
frame monitor → `performance`; network logger → `api`/`network`; console capture
→ `debugConsole`; init/self-messages → `system`).

### 2. Console capture — `LayerXConsoleCapture`

New `lib/src/services/logger/layerx_console_capture.dart`, installed from
`LayerXDebugger.initialize()` (debug/profile only):

- **`debugPrint` override.** Save the previous `debugPrint`, install a wrapper
  that ingests the line (`category: debugConsole`, `level: debug`) then forwards
  to the previous one. Idempotent; restores on `reset()` (tests).
- **Zone `print` hook.** `LayerXCrashHandler.runGuarded` already creates the
  guarded zone. Extend it with a `ZoneSpecification(print: …)` that ingests the
  line then calls `parent.print`. This captures raw `print()` and most
  third-party output for apps that wrap `runZonedGuarded` (the documented
  pattern). Apps that don't wrap still get the `debugPrint` override.
- **Reentrancy guard (critical).** A `static bool _emitting` flag wraps every
  capture: while ingesting we do not re-capture, and LayerX's own console echo
  (`LayerXConsoleLogger` / `LayerXConsolePrinter`, and the `ingest` failure
  `debugPrint` on log_output.dart) sets the same flag so the debugger's own
  output is never re-ingested. Without this, each captured line would print and
  be recaptured — an infinite feedback loop. This is covered by an explicit
  test.

### 3. Exception categorization (in `LayerXCrashHandler`)

`_record` gains a `category`. Classification:

- `FlutterError.onError`: inspect `details.library` and the exception —
  rendering/widgets library or a `RenderFlex overflowed` / layout message →
  `uiException`; otherwise `framework`. (Level stays as today.)
- `PlatformDispatcher.onError`, guarded-zone errors → `dartException`, or
  `crash` when fatal.
- **Isolate errors:** add `Isolate.current.addErrorListener` behind a
  conditional import — `layerx_isolate_hook_io.dart` (real listener) vs
  `layerx_isolate_hook_web.dart` (no-op) — so the package still compiles for
  web. Category `dartException`.

### 4. Source file + line

Extend `LayerXLogOutput._parseStackTrace` to also extract `file:line:col` from
the first app frame (`(package:foo/bar.dart:12:3)`). Two new optional fields on
`LayerXLogEntry`: `String? sourceFile`, `int? sourceLine` (additive, defaulted
null; added to `copyWith`). Existing screen/method parsing is unchanged.

### 5. Build-mode gating & safety

- Console capture and exception re-categorization install only when
  `!kReleaseMode` (and honor `config.environment`). Release is unchanged:
  crash/error capture stays, viewer stays off, `prod` keeps warning+.
- **Never crash the host:** all new hooks are wrapped so a failure logs and
  continues, matching the existing `initialize()` guard.
- **No duplicate logs:** reuse `LayerXDuplicateGuard`; the reentrancy guard
  prevents console feedback.
- **No leaks:** `debugPrint` override and the isolate listener are restored /
  removed in `reset()`; the zone is scoped to `runGuarded`.
- **Overhead:** a wrapper function call per console line plus an enum field —
  negligible; nothing added to the hot render path.

## Public API / exports

- New: `LayerXLogCategory` (exported).
- `LayerXLogEntry`: `+category`, `+sourceFile`, `+sourceLine` (all additive/
  defaulted). No removals, no signature breaks.
- `LayerXLogOutput.ingest`, `LayerXLog.log`: `+category` optional param.
- No public method is removed or has a required parameter added.

## Testing strategy

TDD, VM tests under `test/` (setup uses `flutter test`; restore `flutter_tester`
with `flutter precache --force --universal` if it goes missing).

- **Category facet:** entry defaults to `app`; `copyWith` round-trips category;
  `ingest` derives `api` when an endpoint is present, `app` otherwise; explicit
  category wins.
- **Console capture:** installing overrides `debugPrint`; a `debugPrint("x")`
  produces one `debugConsole` entry; **reentrancy** — LayerX's own console echo
  does not create entries and there is no unbounded growth; `reset()` restores
  the original `debugPrint`.
- **Exception categorization:** a synthesized `FlutterErrorDetails` with a
  RenderFlex-overflow message → `uiException`; a generic framework error →
  `framework`; a platform/zone error → `dartException`/`crash`.
- **Source location:** a known stack string yields the expected
  `sourceFile`/`sourceLine`; absent frame → nulls.
- **Non-breaking:** the existing logger/crash/store/viewer test suites stay
  green unchanged.

## Backward compatibility

All model and API changes are additive with defaults. Existing apps, existing
call sites, the store, and the current viewer keep working; new entries simply
carry a category (defaulting to `app`) and optional source location. No
migration required.

## Rollout

Ship as a minor version bump with a CHANGELOG entry. Phase 2 (viewer) follows in
a separate spec and release.
