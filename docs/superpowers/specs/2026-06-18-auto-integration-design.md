# Subsystem A — Intelligent Auto-Integration (Setup CLI)

**Date:** 2026-06-18
**Status:** Approved design, pending spec review
**Scope:** `bin/` (setup CLI) plus one new runtime artifact in `lib/`.

> This is the first of three independently-specced subsystems for the LayerX
> Debugger overhaul. The other two — **B. Runtime Capture & Schema Intelligence**
> and **C. UI/UX + Debugger Journey + FAB** — get their own specs after A ships.

---

## 1. Problem

The current setup CLI (`bin/setup.dart` + `bin/src/steps/`) hardcodes exact file
paths (`lib/app/services/logger_service.dart`, `lib/app/services/https_calls.dart`)
and performs raw regex line-surgery on user source. This caused real breakage
(the "stray comma constructor bug") and offers no reliable idempotency: re-running
risks duplicate imports, duplicate output bindings, and broken files. It also does
not handle `dio`, renamed service classes, or partial/incremental integration.

## 2. Goals

- Detect the LayerX **logger** and **HTTP** services by content, not fixed paths.
- Inject all changes inside **removable marker blocks** so re-runs are atomic and
  idempotent: no duplicate code, imports, registrations, or interceptors.
- **Abort** cleanly if no logger service exists; **skip gracefully** if no HTTP
  service exists.
- Support `dio`, `http`-wrappers, or both coexisting in one project.
- Never blind-edit unrecognized HTTP code — fall back to a guided snippet.
- Leave the project in a known-good state (format + analyze report).

## 3. Non-Goals

- Generic / non-LayerX project support. The architecture gate stays: setup aborts
  on non-LayerX projects (decision: *LayerX-only, but smarter*).
- Runtime capture richness and schema detection (Subsystem B).
- UI changes (Subsystem C).

## 4. Detection (LayerX-scoped, content-based)

The existing folder-structure architecture gate (`LayerXDetectorStep`) is retained
unchanged — it still decides whether the project qualifies as LayerX at all.

A new **integration-target detection** layer scans for the two things the CLI must
bind, by content rather than fixed filename:

- **Logger (required):** scan `lib/app/services/**/*.dart` for a class declaring a
  `static final Logger` field (the `logger` package). Matches `LoggerService` or any
  renamed equivalent. Captures: file path, class name, and the character span of the
  `Logger( ... )` constructor call.
- **HTTP (optional):** scan `lib/app/**/*.dart` (services first) for:
  - **dio:** any `Dio(` instantiation. Captures file + instantiation site(s).
  - **http wrapper:** a class whose name matches `*Http*|*Api*|*Network*|HttpsCalls`
    AND which references `http.` (the `http` package). Captures file + class.

Output is a typed report:

```text
IntegrationTargets {
  logger:   { found, filePath, className, loggerCtorSpan } | notFound
  dio:      { found, filePath, instantiationSites }        | notFound
  httpWrap: { found, filePath, className, recordSite? }    | notFound
}
```

`dio` and `httpWrap` may both be present (FesoRide case) — both get wired.

## 5. Injection model — marker blocks

Every injected change is wrapped in sentinel comments so the CLI can find, skip,
replace, or remove it deterministically:

```dart
// layerx:begin(<block-id>) — managed by layerx_debugger, do not edit
...injected lines...
// layerx:end(<block-id>)
```

Block IDs:

| Block ID          | Purpose                                                    |
|-------------------|-----------------------------------------------------------|
| `import:layerx`   | `import 'package:layerx_debugger/...';` lines             |
| `logger-output`   | `LayerXLogInterceptorOutput()` wired into `Logger(output:)`|
| `dio-interceptor` | `dio.interceptors.add(LayerXDioInterceptor());`           |
| `http-record`     | `LayerXNetworkLogger.record(...)` call at a response site |

**Re-run algorithm per block:** if the marker pair is present → compare inner
content to the package's current canonical content; replace inner lines if they
drifted, otherwise leave untouched. If absent → insert. Imports use the same
mechanism (one marker block per file collecting LayerX imports). No content-string
guessing; idempotency is guaranteed by the markers.

**Pre-existing manual integration:** if a file already references `LayerX*`
identifiers *outside* any marker block (a hand-done integration), the CLI does not
re-inject — it logs that manual integration was detected and leaves the file alone.

## 6. Per-target behavior

### 6.1 Logger (required)
Inject `LayerXLogInterceptorOutput()` into the detected `Logger(output:)`
constructor, handling the three existing cases — now marker-wrapped and idempotent:
1. No `output:` param → add `output: kDebugMode ? MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()]) : ConsoleOutput(),`
2. `output: ConsoleOutput()` → replace with the `MultiOutput([...])` form.
3. Existing `MultiOutput([...])` without our output → append `LayerXLogInterceptorOutput()`.

The added import line goes in the `import:layerx` block at the top of the file.

### 6.2 Dio (auto)
Insert `dio.interceptors.add(LayerXDioInterceptor());` (marker-wrapped) immediately
after each detected `Dio(...)` instantiation. Adds `import 'package:layerx_debugger/dio.dart';`
in the file's `import:layerx` block.

### 6.3 http wrapper (auto + guided fallback)
- If a legacy `LxHttpInterceptor.record(...)` call exists → replace it with a
  marker-wrapped `LayerXNetworkLogger.record(...)` (preserving the existing
  argument-unpacking logic already in the codebase).
- Else if a single clear response-return site is detectable → inject a
  marker-wrapped `record(...)` there.
- **Else → do not edit.** Print the exact `LayerXNetworkLogger.record(...)` snippet
  plus the file and recommended location, and continue.

## 7. Missing-service behavior

- **No logger found → ABORT.** Exact message:
  > "LayerX LoggerService was not found. Integration cannot continue because logs will not be captured."
- **No HTTP service found → SKIP network integration, continue, succeed.** Print an
  informative message: network interception was skipped because no HTTP/dio service
  was detected, and re-running setup after adding one will integrate it.

## 8. New runtime artifact — `LayerXDioInterceptor`

- A `dio.Interceptor` shipped in the package, forwarding `onResponse` / `onError` to
  `LayerXNetworkLogger.record` / `recordException`.
- **Packaging:** behind a **separate import** `package:layerx_debugger/dio.dart`, with
  `dio` as an **optional dependency** — http-only projects never pull dio in. The CLI
  references this import only when it detected dio. (Implementation note: declare a
  conditional/secondary library entry-point; `dio` lives in `dependencies` but is only
  imported from `lib/dio.dart`, which consumers opt into.)

## 9. Safety & verification

- **Backups:** one-time `.bak` per file on first modification (existing behavior kept).
  Markers additionally enable a future `--uninstall`.
- **Post-patch:** run `dart format` on every touched file, then run `flutter analyze`
  and surface any errors as a **warning summary** (report-only — does not fail setup).
  Directly serves the "no broken files" requirement.

## 10. CLI structure

Refactor `bin/src/steps/` so each step is small, idempotent, and testable:

| Step                 | Responsibility                                              |
|----------------------|------------------------------------------------------------|
| `LayerXDetectorStep` | (unchanged) architecture gate                              |
| `IntegrationScanStep`| NEW — produce the typed `IntegrationTargets` report        |
| `PubspecStep`        | add dep; **resolve real published version** (not hardcoded)|
| `MainDartStep`       | (existing) wrap `main` — converted to marker blocks        |
| `AppWidgetStep`      | (existing) overlay builder — converted to marker blocks    |
| `LoggerBindStep`     | NEW — split from `service_logger_http_step`; logger only   |
| `HttpBindStep`       | NEW — split from `service_logger_http_step`; dio + http     |
| `VerifyStep`         | NEW — format touched files + `flutter analyze` report      |

`service_logger_http_step.dart` is removed once its logic is split and marker-ized.

## 11. Edge cases

- Multiple setup runs → no-ops after the first (markers present).
- Partial integration: logger now, http added later → second run wires only http.
- Renamed logger/http classes → content-based detection still finds them.
- dio-only, http-only, both → each path independent.
- Pre-existing manual `LayerX*` integration outside markers → detected, left alone.
- Missing `output:` param, formatting variations → handled by the three logger cases.
- Drifted injected content (package upgraded) → marker block inner content replaced.

## 12. Testing

Golden-file tests under `test/setup/`:
- Sample source variants for logger (no-output / ConsoleOutput / MultiOutput) and
  HTTP (dio-only / http-wrapper / both / FesoRide-shaped).
- For each: run the step, assert against a golden output file.
- **Idempotency assertion:** running the step twice produces byte-identical output to
  running it once.
- Missing-logger → abort path; missing-http → skip path.

## 13. Acceptance criteria

1. Running setup on a LayerX project with `LoggerService` + `HttpsCalls` (http) wires
   logger output and either auto-injects `record(...)` or prints a guided snippet.
2. Running setup on a project with `dio` auto-adds `LayerXDioInterceptor`.
3. Running setup twice changes nothing the second time (idempotent).
4. A project with no logger aborts with the exact specified message.
5. A project with no HTTP service completes successfully with the skip message.
6. After setup, `flutter analyze` reports no new errors introduced by the CLI.
