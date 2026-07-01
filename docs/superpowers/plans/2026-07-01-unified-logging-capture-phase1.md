# Unified Logging Capture — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture `print`/`debugPrint` console output and Flutter/Dart exceptions into the existing in-app log pipeline, grouped by a new `LayerXLogCategory` facet, without breaking the current logger, model, store, or viewer.

**Architecture:** Every capture source feeds the single existing choke point `LayerXLogOutput.ingest()` → `LayerXLogStore`. One additive model facet (`category`) plus two optional location fields. New capture is install-time glue in `LayerXDebugger.initialize()`, gated to debug/profile. A reentrancy guard stops LayerX's own console echo from being re-captured.

**Tech Stack:** Dart/Flutter, `flutter_test` (VM), the `logger` package (already a dependency).

---

## Conventions

- **Run tests with:** `flutter test <path>` (VM). If it fails with *"Failed to find … flutter_tester"*, restore it once with `flutter precache --force --universal`, then re-run. Do **not** use `--platform chrome` for `test/setup/**` or any test importing `dart:isolate`.
- After each task: `dart analyze lib/ test/` must report **no issues** before committing.
- TDD: write the test, watch it fail, implement minimally, watch it pass, commit.

## File Structure

**Create:**
- `lib/src/config/enums/layerx_log_category.dart` — the category enum (label/color/icon).
- `lib/src/config/utils/layerx_stack_location.dart` — pure `file:line` extractor.
- `lib/src/services/logger/layerx_console_capture.dart` — `debugPrint`/`print` capture + reentrancy guard.
- `lib/src/services/crash/layerx_error_classifier.dart` — pure exception→category classifier.
- `lib/src/services/crash/layerx_isolate_hook.dart` — conditional-import switcher.
- `lib/src/services/crash/layerx_isolate_hook_stub.dart` — web/no-op.
- `lib/src/services/crash/layerx_isolate_hook_io.dart` — real isolate listener.
- Tests: `test/logging/log_category_test.dart`, `test/logging/log_entry_category_test.dart`, `test/logging/stack_location_test.dart`, `test/logging/log_output_category_test.dart`, `test/logging/console_capture_test.dart`, `test/logging/console_feedback_test.dart`, `test/logging/error_classifier_test.dart`, `test/logging/isolate_decode_test.dart`, `test/logging/producer_category_test.dart`.

**Modify:**
- `lib/src/mvvm/model/layerx_log_entry.dart` — add `category`, `sourceFile`, `sourceLine`.
- `lib/src/services/logger/layerx_log_output.dart` — `category` param + derivation + source location.
- `lib/src/services/logger/layerx_log.dart` — optional `category` on `log`/`_emit`.
- `lib/src/config/utils/layerx_console_printer.dart` — wrap `debugPrint` with the guard.
- `lib/src/services/logger/layerx_console_logger.dart` — wrap emits with the guard.
- `lib/src/services/crash/layerx_crash_handler.dart` — classify + zone `print` hook + isolate hook.
- `lib/src/core/layerx_debugger_initializer.dart` — install console capture (debug/profile only) + reset.
- `lib/layerx_debugger.dart` — export the category enum.
- `pubspec.yaml`, `CHANGELOG.md` — version bump.

---

### Task 1: `LayerXLogCategory` enum

**Files:**
- Create: `lib/src/config/enums/layerx_log_category.dart`
- Modify: `lib/layerx_debugger.dart`
- Test: `test/logging/log_category_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/log_category_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  test('every category exposes a non-empty label, a color and an icon', () {
    for (final c in LayerXLogCategory.values) {
      expect(c.label, isNotEmpty, reason: '${c.name} label');
      expect(c.color, isA<Color>());
      expect(c.icon, isA<IconData>());
    }
  });

  test('covers the 12 product buckets', () {
    expect(LayerXLogCategory.values.map((c) => c.name).toSet(), {
      'app', 'framework', 'uiException', 'dartException', 'network', 'api',
      'navigation', 'lifecycle', 'performance', 'crash', 'debugConsole',
      'system',
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/log_category_test.dart`
Expected: FAIL — `layerx_log_category.dart` does not exist (compile error).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/config/enums/layerx_log_category.dart
import 'package:flutter/material.dart';

/// The functional section a log entry belongs to.
///
/// A category is orthogonal to [LayerXLogLevel] (severity) and
/// [LayerXLogSource] (ownership): it groups entries into the sections shown in
/// the in-app viewer (Debug Console, UI Exceptions, Navigation, …).
enum LayerXLogCategory {
  app,
  framework,
  uiException,
  dartException,
  network,
  api,
  navigation,
  lifecycle,
  performance,
  crash,
  debugConsole,
  system;

  /// A human-readable label shown in the viewer.
  String get label {
    switch (this) {
      case LayerXLogCategory.app:
        return 'App Logs';
      case LayerXLogCategory.framework:
        return 'Flutter Framework';
      case LayerXLogCategory.uiException:
        return 'UI Exceptions';
      case LayerXLogCategory.dartException:
        return 'Dart Exceptions';
      case LayerXLogCategory.network:
        return 'Network';
      case LayerXLogCategory.api:
        return 'API';
      case LayerXLogCategory.navigation:
        return 'Navigation';
      case LayerXLogCategory.lifecycle:
        return 'Lifecycle';
      case LayerXLogCategory.performance:
        return 'Performance';
      case LayerXLogCategory.crash:
        return 'Crash Logs';
      case LayerXLogCategory.debugConsole:
        return 'Debug Console';
      case LayerXLogCategory.system:
        return 'System Logs';
    }
  }

  /// The accent color used for this category in the viewer.
  Color get color {
    switch (this) {
      case LayerXLogCategory.app:
        return const Color(0xFF39D353);
      case LayerXLogCategory.framework:
        return const Color(0xFF38BDF8);
      case LayerXLogCategory.uiException:
        return const Color(0xFFFF5C57);
      case LayerXLogCategory.dartException:
        return const Color(0xFFFF9F45);
      case LayerXLogCategory.network:
        return const Color(0xFF22D3EE);
      case LayerXLogCategory.api:
        return const Color(0xFF38BDF8);
      case LayerXLogCategory.navigation:
        return const Color(0xFFA78BFA);
      case LayerXLogCategory.lifecycle:
        return const Color(0xFF3FE06B);
      case LayerXLogCategory.performance:
        return const Color(0xFFE3B341);
      case LayerXLogCategory.crash:
        return const Color(0xFFB71C1C);
      case LayerXLogCategory.debugConsole:
        return const Color(0xFF6FA982);
      case LayerXLogCategory.system:
        return const Color(0xFF9E9E9E);
    }
  }

  /// A Material icon used as this category's glyph in the viewer.
  IconData get icon {
    switch (this) {
      case LayerXLogCategory.app:
        return Icons.code;
      case LayerXLogCategory.framework:
        return Icons.flutter_dash;
      case LayerXLogCategory.uiException:
        return Icons.widgets_outlined;
      case LayerXLogCategory.dartException:
        return Icons.bug_report_outlined;
      case LayerXLogCategory.network:
        return Icons.wifi_tethering;
      case LayerXLogCategory.api:
        return Icons.swap_vert;
      case LayerXLogCategory.navigation:
        return Icons.alt_route;
      case LayerXLogCategory.lifecycle:
        return Icons.autorenew;
      case LayerXLogCategory.performance:
        return Icons.speed;
      case LayerXLogCategory.crash:
        return Icons.dangerous_outlined;
      case LayerXLogCategory.debugConsole:
        return Icons.terminal;
      case LayerXLogCategory.system:
        return Icons.settings_suggest_outlined;
    }
  }
}
```

Add the export to `lib/layerx_debugger.dart` in the Models section, right after the `layerx_log_source.dart` export:

```dart
export 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/log_category_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/config/enums/layerx_log_category.dart lib/layerx_debugger.dart test/logging/log_category_test.dart
git commit -m "feat(logging): add LayerXLogCategory facet enum"
```

---

### Task 2: Add `category` + source location to `LayerXLogEntry`

**Files:**
- Modify: `lib/src/mvvm/model/layerx_log_entry.dart`
- Test: `test/logging/log_entry_category_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/log_entry_category_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';

LayerXLogEntry _entry() => LayerXLogEntry(
      id: '1',
      dedupKey: 'k',
      timestamp: DateTime(2026),
      level: LayerXLogLevel.info,
      source: LayerXLogSource.app,
      message: 'm',
      journey: const [],
      extras: const {},
    );

void main() {
  test('category defaults to app and location defaults to null', () {
    final e = _entry();
    expect(e.category, LayerXLogCategory.app);
    expect(e.sourceFile, isNull);
    expect(e.sourceLine, isNull);
  });

  test('copyWith round-trips category and source location', () {
    final e = _entry().copyWith(
      category: LayerXLogCategory.debugConsole,
      sourceFile: 'lib/main.dart',
      sourceLine: 42,
    );
    expect(e.category, LayerXLogCategory.debugConsole);
    expect(e.sourceFile, 'lib/main.dart');
    expect(e.sourceLine, 42);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/log_entry_category_test.dart`
Expected: FAIL — no named parameter `category` on `LayerXLogEntry`.

- [ ] **Step 3: Write minimal implementation**

In `lib/src/mvvm/model/layerx_log_entry.dart`:

Add the import at the top (after the existing enum imports):

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

Add these three fields immediately after the `source` field (around line 25):

```dart
  /// The functional section this entry belongs to (Debug Console, UI
  /// Exceptions, Navigation, …). Defaults to [LayerXLogCategory.app].
  final LayerXLogCategory category;

  /// The source file the entry originated from, when parseable from the stack.
  final String? sourceFile;

  /// The 1-based line number in [sourceFile], when parseable.
  final int? sourceLine;
```

In the constructor parameter list, add (after `required this.source,`):

```dart
    this.category = LayerXLogCategory.app,
    this.sourceFile,
    this.sourceLine,
```

In `copyWith`'s parameter list add:

```dart
    LayerXLogCategory? category,
    String? sourceFile,
    int? sourceLine,
```

In the `copyWith` body's `LayerXLogEntry(...)` call add (after `source: source ?? this.source,`):

```dart
      category: category ?? this.category,
      sourceFile: sourceFile ?? this.sourceFile,
      sourceLine: sourceLine ?? this.sourceLine,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/log_entry_category_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Verify nothing else broke, then commit**

Run: `flutter test test/ && dart analyze lib/`
Expected: all existing tests PASS, analyze clean.

```bash
git add lib/src/mvvm/model/layerx_log_entry.dart test/logging/log_entry_category_test.dart
git commit -m "feat(logging): add category + source location to LayerXLogEntry"
```

---

### Task 3: `LayerXStackLocation` — parse `file:line`

**Files:**
- Create: `lib/src/config/utils/layerx_stack_location.dart`
- Test: `test/logging/stack_location_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/stack_location_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/utils/layerx_stack_location.dart';

void main() {
  test('extracts file and line from the first app frame', () {
    const trace = '#0      MyClass.method (package:my_app/screens/home.dart:42:13)\n'
        '#1      main (package:my_app/main.dart:5:3)';
    final loc = LayerXStackLocation.parse(trace, packageName: 'my_app');
    expect(loc.file, 'package:my_app/screens/home.dart');
    expect(loc.line, 42);
  });

  test('skips layerx frames when no package name is given', () {
    const trace = '#0      LayerXLog._emit (package:layerx_debugger/x.dart:9:1)\n'
        '#1      Foo.bar (package:app/foo.dart:7:2)';
    final loc = LayerXStackLocation.parse(trace);
    expect(loc.file, 'package:app/foo.dart');
    expect(loc.line, 7);
  });

  test('returns nulls when no usable frame exists', () {
    final loc = LayerXStackLocation.parse('no frames here');
    expect(loc.file, isNull);
    expect(loc.line, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/stack_location_test.dart`
Expected: FAIL — `layerx_stack_location.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/config/utils/layerx_stack_location.dart
/// A parsed source location: a `package:` uri and a 1-based line number.
class LayerXStackLocation {
  final String? file;
  final int? line;
  const LayerXStackLocation(this.file, this.line);

  static const empty = LayerXStackLocation(null, null);

  /// Extracts the first meaningful `(package:…/file.dart:line:col)` frame from
  /// [trace]. Frames inside `layerx_debugger` are skipped. When [packageName]
  /// is given, only frames from that package are considered.
  static LayerXStackLocation parse(String trace, {String? packageName}) {
    final re = RegExp(r'\((package:[^\s:]+):(\d+):\d+\)');
    for (final line in trace.split('\n')) {
      final m = re.firstMatch(line);
      if (m == null) continue;
      final uri = m.group(1)!;
      if (uri.contains('package:layerx_debugger')) continue;
      if (packageName != null && !uri.contains('package:$packageName/')) {
        continue;
      }
      return LayerXStackLocation(uri, int.tryParse(m.group(2)!));
    }
    return empty;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/stack_location_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/config/utils/layerx_stack_location.dart test/logging/stack_location_test.dart
git commit -m "feat(logging): add LayerXStackLocation file:line parser"
```

---

### Task 4: Thread `category` + location through `LayerXLogOutput.ingest`

**Files:**
- Modify: `lib/src/services/logger/layerx_log_output.dart`
- Modify: `lib/src/services/logger/layerx_log.dart`
- Test: `test/logging/log_output_category_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/log_output_category_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('derives api when an endpoint is present', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'call',
      endpoint: '/users',
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.api);
  });

  test('derives app when there is no endpoint', () {
    LayerXLogOutput.ingest(level: LayerXLogLevel.info, message: 'hi');
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.app);
  });

  test('an explicit category wins over derivation', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.debug,
      message: 'printed',
      category: LayerXLogCategory.debugConsole,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.debugConsole);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/log_output_category_test.dart`
Expected: FAIL — `ingest` has no `category` parameter.

- [ ] **Step 3: Write minimal implementation**

In `lib/src/services/logger/layerx_log_output.dart`:

Add imports:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/utils/layerx_stack_location.dart';
```

Add a parameter to `ingest` (after `required String message,`):

```dart
    LayerXLogCategory? category,
```

Inside `ingest`, after `final source = LayerXSourceDetector.detect(...)` block, add the location parse and category derivation:

```dart
      final location = LayerXStackLocation.parse(
        (stackTrace ?? StackTrace.current).toString(),
        packageName: packageName,
      );
      final resolvedCategory = category ??
          (endpoint != null
              ? LayerXLogCategory.api
              : LayerXLogCategory.app);
```

In the `LayerXLogStore.add(LayerXLogEntry(...))` call, add these three arguments (after `source: source,`):

```dart
        category: resolvedCategory,
        sourceFile: location.file,
        sourceLine: location.line,
```

Then thread an optional category through the manual logger so producers can tag through `LayerXLog.log`. In `lib/src/services/logger/layerx_log.dart`:

Add the import:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

Add `LayerXLogCategory? category,` to the parameter list of `log(...)` (after `required String message,`) and of `_emit(...)` (after `String message, {`). In `log`'s body pass `category: category,` into the `_emit(...)` call, and in `_emit`'s body pass `category: category,` into the `LayerXLogOutput.ingest(...)` call.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/log_output_category_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/ && dart analyze lib/`
Expected: all PASS, analyze clean.

```bash
git add lib/src/services/logger/layerx_log_output.dart lib/src/services/logger/layerx_log.dart test/logging/log_output_category_test.dart
git commit -m "feat(logging): thread category + source location through ingest"
```

---

### Task 5: `LayerXConsoleCapture` — debugPrint override + reentrancy guard

**Files:**
- Create: `lib/src/services/logger/layerx_console_capture.dart`
- Test: `test/logging/console_capture_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/console_capture_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXConsoleCapture.reset);

  test('a debugPrint after install is captured as a debugConsole entry', () {
    LayerXConsoleCapture.install();
    debugPrint('hello from debugPrint');
    final logs = LayerXLogStore.logs;
    expect(logs, hasLength(1));
    expect(logs.first.category, LayerXLogCategory.debugConsole);
    expect(logs.first.message, 'hello from debugPrint');
  });

  test('guard() suppresses capture of LayerX-owned output', () {
    LayerXConsoleCapture.install();
    LayerXConsoleCapture.guard(() => debugPrint('internal echo'));
    expect(LayerXLogStore.logs, isEmpty);
  });

  test('reset restores the original debugPrint (no capture after reset)', () {
    LayerXConsoleCapture.install();
    LayerXConsoleCapture.reset();
    debugPrint('after reset');
    expect(LayerXLogStore.logs, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/console_capture_test.dart`
Expected: FAIL — `layerx_console_capture.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/services/logger/layerx_console_capture.dart
import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';

/// Captures framework/app console output (`debugPrint`, and — via the guarded
/// zone — `print`) into the LayerX log store under
/// [LayerXLogCategory.debugConsole].
///
/// A reentrancy [guard] prevents LayerX's own console echo (and any output
/// produced while ingesting) from being re-captured, which would otherwise
/// create an unbounded feedback loop.
class LayerXConsoleCapture {
  LayerXConsoleCapture._();

  static bool _installed = false;
  static bool _emitting = false;
  static DebugPrintCallback? _previousDebugPrint;

  /// Whether LayerX is currently emitting its own output (capture is skipped).
  static bool get isEmitting => _emitting;

  /// Installs the `debugPrint` override. Idempotent.
  static void install() {
    if (_installed) return;
    _installed = true;
    _previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _previousDebugPrint!(message, wrapWidth: wrapWidth);
      capture(message);
    };
  }

  /// Restores the original `debugPrint`. Safe to call when not installed.
  static void reset() {
    if (!_installed) return;
    if (_previousDebugPrint != null) debugPrint = _previousDebugPrint!;
    _previousDebugPrint = null;
    _installed = false;
    _emitting = false;
  }

  /// Ingests a single captured console [message] unless suppressed by [guard].
  static void capture(String? message) {
    if (_emitting || message == null || message.isEmpty) return;
    guard(() => LayerXLogOutput.ingest(
          level: LayerXLogLevel.debug,
          message: message,
          category: LayerXLogCategory.debugConsole,
        ));
  }

  /// Runs [body] with capture suppressed. Wrap every LayerX-owned console write
  /// so it is not re-captured.
  static T guard<T>(T Function() body) {
    final previous = _emitting;
    _emitting = true;
    try {
      return body();
    } finally {
      _emitting = previous;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/console_capture_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/services/logger/layerx_console_capture.dart test/logging/console_capture_test.dart
git commit -m "feat(logging): add LayerXConsoleCapture with reentrancy guard"
```

---

### Task 6: Stop LayerX's own console echo from being re-captured

**Files:**
- Modify: `lib/src/config/utils/layerx_console_printer.dart`
- Modify: `lib/src/services/logger/layerx_console_logger.dart`
- Test: `test/logging/console_feedback_test.dart`

This wraps LayerX's two console-writing primitives in the guard so that a normal
`LayerXLog.i(...)` (which echoes to the console) does not also create a spurious
`debugConsole` entry.

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/console_feedback_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXConsoleCapture.reset);

  test('LayerXLog.i produces exactly one entry (its own), not a console echo',
      () {
    LayerXConsoleCapture.install();
    LayerXLog.i('user tapped save');
    final logs = LayerXLogStore.logs;
    // One app-log entry, and no extra debugConsole entry from the echo.
    expect(logs.where((l) => l.category == LayerXLogCategory.debugConsole),
        isEmpty);
    expect(logs.where((l) => l.message == 'user tapped save'), hasLength(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/console_feedback_test.dart`
Expected: FAIL — the console echo is captured, producing an extra `debugConsole` entry (the first `expect` fails).

- [ ] **Step 3: Write minimal implementation**

In `lib/src/config/utils/layerx_console_printer.dart` add the import:

```dart
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
```

Change the body of `printLine` to guard the write:

```dart
  static void printLine(
    LayerXLogLevel level,
    String message, {
    required bool colors,
  }) {
    LayerXConsoleCapture.guard(
        () => debugPrint(formatLine(level, message, colors: colors)));
  }
```

Change the loop body of `printBox` to guard each write:

```dart
    for (final line in box(
      title: title,
      lines: lines,
      level: level,
      colors: colors,
    )) {
      LayerXConsoleCapture.guard(() => debugPrint(line));
    }
```

In `lib/src/services/logger/layerx_console_logger.dart` add the import:

```dart
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
```

Wrap each of the six emit methods (`t`, `d`, `i`, `w`, `e`, `f`) so the `logger`
package's `print`-based output is guarded. For example `t`:

```dart
  static void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXConsoleCapture.guard(
          () => instance.t(message, error: error, stackTrace: stackTrace));
```

Apply the identical wrapping to `d`, `i`, `w`, `e`, and `f` (same shape, just the
method letter changes).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/console_feedback_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/ && dart analyze lib/`
Expected: all PASS, analyze clean.

```bash
git add lib/src/config/utils/layerx_console_printer.dart lib/src/services/logger/layerx_console_logger.dart test/logging/console_feedback_test.dart
git commit -m "feat(logging): guard LayerX console echo from re-capture"
```

---

### Task 7: `LayerXErrorClassifier` — categorize framework/Dart exceptions

**Files:**
- Create: `lib/src/services/crash/layerx_error_classifier.dart`
- Test: `test/logging/error_classifier_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/error_classifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_error_classifier.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  test('a RenderFlex overflow is a UI exception', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'rendering library',
      description: 'A RenderFlex overflowed by 42 pixels on the right.',
    );
    expect(c, LayerXLogCategory.uiException);
  });

  test('a widgets-library error is a UI exception', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'widgets library',
      description: 'setState() called after dispose()',
    );
    expect(c, LayerXLogCategory.uiException);
  });

  test('a generic framework error falls back to framework', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'services library',
      description: 'MissingPluginException',
    );
    expect(c, LayerXLogCategory.framework);
  });

  test('a fatal uncaught error is a crash; non-fatal is a dart exception', () {
    expect(LayerXErrorClassifier.classifyUncaught(fatal: true),
        LayerXLogCategory.crash);
    expect(LayerXErrorClassifier.classifyUncaught(fatal: false),
        LayerXLogCategory.dartException);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/error_classifier_test.dart`
Expected: FAIL — `layerx_error_classifier.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/services/crash/layerx_error_classifier.dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

/// Classifies captured errors into a [LayerXLogCategory].
class LayerXErrorClassifier {
  LayerXErrorClassifier._();

  /// Categorizes a `FlutterError.onError` report from its [library] tag and
  /// [description]. Rendering/widget/layout problems (including overflow) are
  /// [LayerXLogCategory.uiException]; everything else is
  /// [LayerXLogCategory.framework].
  static LayerXLogCategory classifyFlutterError({
    String? library,
    String? description,
  }) {
    final lib = (library ?? '').toLowerCase();
    final desc = (description ?? '').toLowerCase();
    final isUi = lib.contains('rendering') ||
        lib.contains('widgets') ||
        lib.contains('painting') ||
        desc.contains('overflow') ||
        desc.contains('renderflex') ||
        desc.contains('constraints') ||
        desc.contains('setstate');
    return isUi ? LayerXLogCategory.uiException : LayerXLogCategory.framework;
  }

  /// Categorizes an uncaught async/platform/zone/isolate error.
  static LayerXLogCategory classifyUncaught({required bool fatal}) =>
      fatal ? LayerXLogCategory.crash : LayerXLogCategory.dartException;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/error_classifier_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/services/crash/layerx_error_classifier.dart test/logging/error_classifier_test.dart
git commit -m "feat(logging): add LayerXErrorClassifier for exception categories"
```

---

### Task 8: Isolate error capture (conditional import)

**Files:**
- Create: `lib/src/services/crash/layerx_isolate_hook.dart`
- Create: `lib/src/services/crash/layerx_isolate_hook_stub.dart`
- Create: `lib/src/services/crash/layerx_isolate_hook_io.dart`
- Test: `test/logging/isolate_decode_test.dart`

The isolate error listener receives a two-element `List` `[errorString,
stackString]`. The decode logic is a pure function (testable); the listener
wiring is thin glue.

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/isolate_decode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_isolate_hook_io.dart';

void main() {
  test('decodes [error, stack] pair into a message and stack trace', () {
    final decoded = decodeIsolateError(['Boom', '#0 main (a.dart:1:1)']);
    expect(decoded.message, 'Boom');
    expect(decoded.stack.toString(), contains('a.dart'));
  });

  test('handles a null stack element', () {
    final decoded = decodeIsolateError(['Boom', null]);
    expect(decoded.message, 'Boom');
    expect(decoded.stack, StackTrace.empty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/isolate_decode_test.dart`
Expected: FAIL — `layerx_isolate_hook_io.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/services/crash/layerx_isolate_hook_io.dart
import 'dart:isolate';

/// A decoded isolate error.
class IsolateError {
  final String message;
  final StackTrace stack;
  const IsolateError(this.message, this.stack);
}

/// Decodes the `[error, stack]` pair an isolate error listener delivers.
IsolateError decodeIsolateError(List<dynamic> pair) {
  final message = pair.isNotEmpty ? '${pair[0]}' : 'Isolate error';
  final rawStack = pair.length > 1 ? pair[1] : null;
  final stack = rawStack == null
      ? StackTrace.empty
      : StackTrace.fromString(rawStack.toString());
  return IsolateError(message, stack);
}

/// Adds a listener for uncaught errors on the current isolate, forwarding each
/// to [onError]. Returns a close function that removes the listener.
void Function() installIsolateErrorHook(
    void Function(Object error, StackTrace stack) onError) {
  final port = RawReceivePort((dynamic message) {
    final decoded = decodeIsolateError(message as List<dynamic>);
    onError(decoded.message, decoded.stack);
  });
  Isolate.current.addErrorListener(port.sendPort);
  return () {
    Isolate.current.removeErrorListener(port.sendPort);
    port.close();
  };
}
```

```dart
// lib/src/services/crash/layerx_isolate_hook_stub.dart
/// Web/no-op fallback: isolates are not available, so this does nothing.
void Function() installIsolateErrorHook(
        void Function(Object error, StackTrace stack) onError) =>
    () {};
```

```dart
// lib/src/services/crash/layerx_isolate_hook.dart
/// Platform-neutral entry point for the isolate error hook.
///
/// Resolves to the `dart:isolate` implementation on native platforms and a
/// no-op on the web (where `dart:isolate` is unavailable).
export 'layerx_isolate_hook_stub.dart'
    if (dart.library.io) 'layerx_isolate_hook_io.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/isolate_decode_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/services/crash/layerx_isolate_hook.dart lib/src/services/crash/layerx_isolate_hook_stub.dart lib/src/services/crash/layerx_isolate_hook_io.dart test/logging/isolate_decode_test.dart
git commit -m "feat(logging): add cross-platform isolate error hook"
```

---

### Task 9: Wire categories + isolate + zone print into `LayerXCrashHandler`

**Files:**
- Modify: `lib/src/services/crash/layerx_crash_handler.dart`
- Test: `test/logging/crash_category_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/crash_category_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('FlutterError.onError routes a RenderFlex overflow to uiException', () {
    LayerXCrashHandler.install();
    FlutterError.onError!(FlutterErrorDetails(
      exception: FlutterError('A RenderFlex overflowed by 3.0 pixels.'),
      library: 'rendering library',
      context: ErrorDescription('during layout'),
    ));
    final entry =
        LayerXLogStore.logs.firstWhere((l) => l.message.contains('RenderFlex'));
    expect(entry.category, LayerXLogCategory.uiException);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/crash_category_test.dart`
Expected: FAIL — captured entry's category is `app` (default), not `uiException`.

- [ ] **Step 3: Write minimal implementation**

In `lib/src/services/crash/layerx_crash_handler.dart` add imports:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/services/crash/layerx_error_classifier.dart';
import 'package:layerx_debugger/src/services/crash/layerx_isolate_hook.dart';
```

Add a field to hold the isolate closer (next to `_previousFlutterOnError`):

```dart
  static void Function()? _isolateClose;
```

In the `FlutterError.onError` handler, compute a category and pass it. Replace the
`_record(...)` call inside that handler with:

```dart
        _record(
          details.exceptionAsString(),
          details.exception,
          details.stack,
          fatal: false,
          library: details.library,
          category: LayerXErrorClassifier.classifyFlutterError(
            library: details.library,
            description: details.exceptionAsString(),
          ),
        );
```

In the `PlatformDispatcher.instance.onError` handler, replace its `_record(...)`
call with:

```dart
        _record(error.toString(), error, stack,
            fatal: true, category: LayerXErrorClassifier.classifyUncaught(fatal: true));
```

Install the isolate hook at the end of `install()` (after the platform handler):

```dart
    _isolateClose = installIsolateErrorHook((error, stack) {
      final config = LayerXDebugger.config;
      if (config.enableCrashLogs) {
        _record(error.toString(), error, stack,
            fatal: true,
            category: LayerXErrorClassifier.classifyUncaught(fatal: true));
        config.onCrash?.call(error, stack, true);
      }
    });
```

Update `runGuarded` to also record zone errors with a category **and** capture
zone `print`. Replace the whole method with:

```dart
  static R? runGuarded<R>(R Function() body) {
    return runZonedGuarded<R>(
      body,
      (error, stack) {
        final config = LayerXDebugger.config;
        if (config.enableCrashLogs) {
          _record(error.toString(), error, stack,
              fatal: true,
              category: LayerXErrorClassifier.classifyUncaught(fatal: true));
          config.onCrash?.call(error, stack, true);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line);
          LayerXConsoleCapture.capture(line);
        },
      ),
    );
  }
```

Add the console-capture import for the zone hook:

```dart
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
```

Update the `_record` signature to accept a category (default `app`) and pass it
to `ingest`. Change the signature and the `ingest` call:

```dart
  static void _record(
    String message,
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? library,
    LayerXLogCategory category = LayerXLogCategory.app,
  }) {
    LayerXLogOutput.ingest(
      level: fatal ? LayerXLogLevel.fatal : LayerXLogLevel.error,
      message: fatal ? '💀 FATAL: $message' : message,
      category: category,
      error: error,
      stackTrace: stack,
      extras: {
        if (library != null) 'library': library,
        if (fatal) 'fatal': true,
      },
      packageName: LayerXDebugger.config.packageName,
    );
  }
```

Finally, add isolate teardown so tests and re-inits don't leak. Add to the
existing `_installed` reset path — if none exists, add a `uninstall()` used by
tests:

```dart
  /// Removes the isolate error listener. Intended for tests/hot-restart.
  static void uninstall() {
    _isolateClose?.call();
    _isolateClose = null;
    _installed = false;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/crash_category_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/ && dart analyze lib/`
Expected: all PASS, analyze clean.

```bash
git add lib/src/services/crash/layerx_crash_handler.dart test/logging/crash_category_test.dart
git commit -m "feat(logging): categorize crash-handler errors + capture zone print + isolate errors"
```

---

### Task 10: Tag remaining producers + install console capture in `initialize`

**Files:**
- Modify: `lib/src/services/route/layerx_route_observer.dart`
- Modify: `lib/src/services/performance/layerx_frame_monitor.dart`
- Modify: `lib/src/services/network/layerx_network_logger.dart`
- Modify: `lib/src/core/layerx_debugger_initializer.dart`
- Test: `test/logging/producer_category_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/producer_category_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('a recorded HTTP exchange is categorized as api', () {
    LayerXNetworkLogger.record(
      endpoint: 'https://x/y',
      method: 'GET',
      statusCode: 200,
      responseBody: '{"ok":true}',
      durationMs: 12,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.api);
  });

  test('a transport exception is categorized as network', () {
    LayerXNetworkLogger.recordException(
      endpoint: 'https://x/y',
      method: 'GET',
      error: 'SocketException: failed',
      durationMs: 5,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.network);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logging/producer_category_test.dart`
Expected: FAIL — both entries default to `api`/`app`, so the `network` case fails (and the `api` case may pass by derivation — the `network` assertion is the red).

- [ ] **Step 3: Write minimal implementation**

**Route observer** — in `lib/src/services/route/layerx_route_observer.dart`, add the import:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

In the `LayerXLogStore.add(LayerXLogEntry(...))` call, add after `source: LayerXLogSource.app,`:

```dart
      category: LayerXLogCategory.navigation,
```

**Frame monitor** — in `lib/src/services/performance/layerx_frame_monitor.dart`, add the import:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

In its `LayerXLog.log(...)` call, add:

```dart
        category: LayerXLogCategory.performance,
```

**Network logger** — in `lib/src/services/network/layerx_network_logger.dart`, add the import:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

In the `LayerXLogStore.add(LayerXLogEntry(...))` call (the `record` success path), add after `source: source,`:

```dart
        category: LayerXLogCategory.api,
```

In the `recordException` `LayerXLogOutput.ingest(...)` call, add:

```dart
      category: LayerXLogCategory.network,
```

In the `recordParsingError` `LayerXLogOutput.ingest(...)` call, add:

```dart
      category: LayerXLogCategory.api,
```

**Initializer** — in `lib/src/core/layerx_debugger_initializer.dart`, add imports:

```dart
import 'package:flutter/foundation.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
```

In `initialize()`, inside the `try {`, after `LayerXCrashHandler.install();`'s
block, install console capture in debug/profile only:

```dart
      if (!kReleaseMode && _config.enableCrashLogs) {
        LayerXConsoleCapture.install();
      }
```

In `resetForTesting()`, add:

```dart
    LayerXConsoleCapture.reset();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logging/producer_category_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/ && dart analyze lib/`
Expected: all PASS, analyze clean.

```bash
git add lib/src/services/route/layerx_route_observer.dart lib/src/services/performance/layerx_frame_monitor.dart lib/src/services/network/layerx_network_logger.dart lib/src/core/layerx_debugger_initializer.dart test/logging/producer_category_test.dart
git commit -m "feat(logging): tag producers with categories + install console capture (debug/profile)"
```

---

### Task 11: Version bump, CHANGELOG, final verification

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump the version**

In `pubspec.yaml` change `version: 1.2.3` to `version: 1.3.0`.

- [ ] **Step 2: Add the CHANGELOG entry**

Insert at the top of `CHANGELOG.md`, above `## 1.2.3`:

```markdown
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
```

- [ ] **Step 3: Full verification**

Run: `flutter test test/ && dart analyze lib/ test/`
Expected: all tests PASS, analyze reports no issues.

Run: `rm -rf example/build && flutter pub publish --dry-run`
Expected: validation passes (aside from the expected uncommitted-files / git warnings).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(logging): bump to 1.3.0 for unified capture (Phase 1)"
```

---

## Self-Review

- **Spec coverage:** Framework exceptions (Task 9 classifier + crash handler), Dart/async/platform (Task 9), isolate (Tasks 8–9), console `print`/`debugPrint` (Tasks 5–6, zone hook in 9), categories (Tasks 1–4, 9–10), source file/line (Tasks 3–4), build-mode gating (Task 10), reentrancy/no-duplicate/no-leak (Tasks 5–6, 9 `uninstall`), non-breaking (defaults throughout; `flutter test test/` gate each task) — all mapped.
- **Placeholders:** none — every code and test step is complete.
- **Type consistency:** `LayerXConsoleCapture.guard/capture/install/reset/isEmitting`, `LayerXStackLocation.parse(...).file/.line`, `LayerXErrorClassifier.classifyFlutterError/classifyUncaught`, `installIsolateErrorHook`/`decodeIsolateError`, and the `ingest(..., category:)` / `LayerXLogEntry(category:, sourceFile:, sourceLine:)` signatures are used identically across tasks.
```
