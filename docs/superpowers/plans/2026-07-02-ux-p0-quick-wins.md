# UX Redesign P0 — Quick Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship the P0 phase of the UX redesign (spec §9, `docs/ux/2026-07-01-layerx-viewer-ux-redesign.md`): stop one-tap data loss, fix the broken AVG LATENCY metric, and unify every copy action behind one component with one wording — as **1.5.0**.

**Architecture:** Two shared primitives land first (a single-issue report formatter in the repository layer; one copy component in the view layer), then the store gains a problem-count/predicate + restore, then each UI fix routes through them. The problem predicate moves INTO the store (view → repo dependency direction) with `LxKit.isProblem` delegating.

**Tech Stack:** Flutter, `flutter_test` (VM). Run `flutter test <path>`; if "Failed to find … flutter_tester", run `flutter precache --force --universal` once and re-run. `dart analyze lib/ test/` must be clean per task. Never stage `example/pubspec.lock`.

**Verified facts this plan relies on (checked 2026-07-02):**
- [lx_dashboard_pane.dart:176](../../lib/src/mvvm/view/shell/lx_dashboard_pane.dart) renders `avgLatency == 0 ? '—' : 'ms'` — the number is missing when data exists.
- [lx_inspector_pane.dart:304](../../lib/src/mvvm/view/shell/lx_inspector_pane.dart) payload copy is silent (`onPressed: () => Clipboard.setData(...)`); stack copy at `:269` uses a local `_copy` with wording "Stack trace copied ✓".
- Shell app bar: export-all at `:208-209` ("Logs copied ✓"), one-tap trash at `:213-218`.
- FAB quick menu: "Export & Copy All" `:278-283` ("All logs copied to clipboard ✓"), "Clear All Logs" `:292-296`.
- Console row copy at `lx_console_pane.dart:244-246` ("Log copied ✓").
- `LayerXBlameEngine.analyze(entry)` → `LayerXBlameInfo{responsibleParty, explanation, qaNote, color, icon}` or null for non-warning/error/fatal.
- `LxKit.isProblem` (error|fatal|warning|responseChanged) at `lx_ui_kit.dart:19`; `LxKit.durationOf` reads `extras['duration_ms']`.
- `LayerXLogStore.exportLogsAsString()` loop body is the per-entry formatting to extract.

---

### Task G1: `LayerXReportFormatter.formatIssue`

**Files:**
- Create: `lib/src/repository/layerx_report_formatter.dart`
- Test: `test/logging/report_formatter_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/report_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_report_formatter.dart';

LayerXLogEntry _entry({
  LayerXLogLevel level = LayerXLogLevel.error,
  String message = 'API Error: 500 on /users',
  int? statusCode = 500,
  String? endpoint = 'https://api.x.com/users',
  String? request = '{"id":1}',
  String? response = '{"error":"boom"}',
  String? stack = '#0 main (a.dart:1:1)',
}) =>
    LayerXLogEntry(
      id: '1', dedupKey: 'k',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      level: level, source: LayerXLogSource.server, message: message,
      endpoint: endpoint, statusCode: statusCode,
      requestPayload: request, responsePayload: response, stackTrace: stack,
      journey: const [], extras: const {},
    );

void main() {
  test('a 500 error report contains every section in plain language', () {
    final report = LayerXReportFormatter.formatIssue(_entry());
    expect(report, contains('API Error: 500 on /users')); // title
    expect(report, contains('Server Error')); // source.label (friendly)
    expect(report, contains('500')); // status
    expect(report, contains('5m ago')); // relative time
    expect(report, contains('{"id":1}')); // request
    expect(report, contains('{"error":"boom"}')); // response
    expect(report, contains('Assign to')); // blame qaNote for a 5xx
    expect(report, contains('#0 main')); // stack
    // Ordering: request appears before response, stack is last.
    expect(report.indexOf('{"id":1}'), lessThan(report.indexOf('{"error":"boom"}')));
    expect(report.indexOf('#0 main'), greaterThan(report.indexOf('Assign to')));
  });

  test('an info entry has no blame section and no stack heading', () {
    final report = LayerXReportFormatter.formatIssue(_entry(
      level: LayerXLogLevel.info,
      message: 'hello',
      statusCode: null,
      endpoint: null,
      request: null,
      response: null,
      stack: null,
    ));
    expect(report, contains('hello'));
    expect(report, isNot(contains('Assign to')));
    expect(report, isNot(contains('Stack trace')));
  });

  test('relative time says "just now" for fresh entries', () {
    final e = _entry();
    final fresh = e.copyWith(timestamp: DateTime.now());
    expect(LayerXReportFormatter.formatIssue(fresh), contains('just now'));
  });
}
```

- [ ] **Step 2: Run it — FAIL (file missing).** `flutter test test/logging/report_formatter_test.dart`

- [ ] **Step 3: Implement**

```dart
// lib/src/repository/layerx_report_formatter.dart
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';

/// Formats a single [LayerXLogEntry] into a complete, plain-language bug
/// report a QA tester can paste into a ticket.
///
/// This is the one formatter every "Copy bug report" action calls, so a report
/// always has the same shape: title → who's affected → status → when →
/// request → response → contract changes → suggested fix → triage note →
/// stack trace.
class LayerXReportFormatter {
  LayerXReportFormatter._();

  /// Renders the shareable report for [log].
  static String formatIssue(LayerXLogEntry log) {
    final b = StringBuffer()
      ..writeln('── Bug report ──')
      ..writeln(log.message.split('\n').first)
      ..writeln()
      ..writeln('Where: ${log.source.label}'
          '${log.endpoint != null ? ' · ${log.endpoint}' : ''}');
    if (log.statusCode != null) b.writeln('Status: ${log.statusCode}');
    b.writeln('When: ${relativeTime(log.timestamp)} '
        '(${log.timestamp.toIso8601String()})');
    if (log.occurrenceCount > 1) {
      b.writeln('Happened ${log.occurrenceCount} times');
    }
    if (log.requestPayload != null) {
      b
        ..writeln()
        ..writeln('What the app sent (request):')
        ..writeln(log.requestPayload);
    }
    if (log.responsePayload != null) {
      b
        ..writeln()
        ..writeln('What the server answered (response):')
        ..writeln(log.responsePayload);
    }
    if (log.responseChanged && log.schemaChanges.isNotEmpty) {
      b
        ..writeln()
        ..writeln('⚠️ The API response changed since the previous call:');
      for (final c in log.schemaChanges) {
        b.writeln('  [${c.label}] ${c.key}: '
            '${c.previousValue ?? '—'} → ${c.currentValue ?? '—'}');
      }
    }
    if (log.suggestedSolution != null) {
      b
        ..writeln()
        ..writeln('Suggested fix: ${log.suggestedSolution}');
    }
    final blame = LayerXBlameEngine.analyze(log);
    if (blame != null) {
      b
        ..writeln()
        ..writeln('Most likely owner: ${blame.responsibleParty}')
        ..writeln('Triage note: ${blame.qaNote}');
    }
    if (log.stackTrace != null &&
        (log.level == LayerXLogLevel.warning ||
            log.level == LayerXLogLevel.error ||
            log.level == LayerXLogLevel.fatal)) {
      b
        ..writeln()
        ..writeln('Stack trace (for the developer):')
        ..writeln(log.stackTrace);
    }
    return b.toString();
  }

  /// "just now", "5m ago", "3h ago", or "2d ago".
  static String relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
```

Note: `source.label` returns e.g. `🖥 Server Error` — the test's `contains('Server Error')` matches. Info-level entries with a stack intentionally omit the stack (non-actionable) — matches the second test.

- [ ] **Step 4: PASS + full suite + analyze.** `flutter test test/logging/report_formatter_test.dart && flutter test test/ && dart analyze lib/ test/`

- [ ] **Step 5: Commit**

```bash
git add lib/src/repository/layerx_report_formatter.dart test/logging/report_formatter_test.dart
git commit -m "feat(viewer): single-issue plain-language report formatter (wires blame engine)"
```

---

### Task G2: `LxCopy` — one copy component

**Files:**
- Create: `lib/src/mvvm/view/shell/lx_copy.dart`
- Test: `test/widgets/lx_copy_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/lx_copy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  Future<int> pumpHost(WidgetTester tester, void Function(BuildContext) onTap) async {
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    return clipboardCalls; // captured by closure; read after taps via tester
  }

  testWidgets('copy shows exactly one snackbar even on rapid double-tap',
      (tester) async {
    await pumpHost(tester, (c) => LxCopy.copy(c, 'text'));
    await tester.tap(find.text('go'));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Copied — paste it into your bug report'), findsOneWidget);
  });

  testWidgets('copyExport on an empty store copies nothing and says so',
      (tester) async {
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => LxCopy.copyExport(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Nothing captured yet'), findsOneWidget);
    expect(clipboardCalls, 0);
  });
}
```

- [ ] **Step 2: Run it — FAIL (file missing).**

- [ ] **Step 3: Implement**

```dart
// lib/src/mvvm/view/shell/lx_copy.dart
// Internal viewer helper — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

/// The single copy path for the viewer: every copy action calls this, so the
/// clipboard behavior and confirmation wording are identical everywhere.
abstract final class LxCopy {
  static const String confirmation = 'Copied — paste it into your bug report';

  /// Copies [text] and shows exactly one confirmation snackbar. Rapid repeat
  /// copies replace the current snackbar instead of queueing behind it.
  static Future<void> copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(LxTheme.snackBar(confirmation));
  }

  /// Copies the full session export, or explains there is nothing to copy.
  static Future<void> copyExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (LayerXLogStore.logs.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(LxTheme.snackBar('Nothing captured yet'));
      return;
    }
    final text = await LayerXLogStore.exportLogsAsString();
    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(LxTheme.snackBar(confirmation));
  }
}
```

- [ ] **Step 4: PASS + full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_copy.dart test/widgets/lx_copy_test.dart
git commit -m "feat(viewer): LxCopy — one copy component, one confirmation, empty-export guard"
```

---

### Task G3: problem predicate + `openProblemCount` in the store

**Files:**
- Modify: `lib/src/repository/layerx_log_store.dart`
- Modify: `lib/src/mvvm/view/shell/lx_ui_kit.dart` (delegate)
- Test: `test/logging/open_problem_count_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/logging/open_problem_count_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry _e(String id, LayerXLogLevel level, {bool changed = false}) =>
    LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026),
      level: level, source: LayerXLogSource.app, message: id,
      responseChanged: changed, journey: const [], extras: const {},
    );

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  test('openProblemCount counts errors, fatals, warnings and schema changes', () {
    LayerXLogStore.add(_e('a', LayerXLogLevel.info));
    LayerXLogStore.add(_e('b', LayerXLogLevel.error));
    LayerXLogStore.add(_e('c', LayerXLogLevel.fatal));
    LayerXLogStore.add(_e('d', LayerXLogLevel.warning));
    LayerXLogStore.add(_e('e', LayerXLogLevel.success, changed: true));
    LayerXLogStore.add(_e('f', LayerXLogLevel.debug));
    expect(LayerXLogStore.openProblemCount, 4);
  });

  test('isProblemEntry matches the level/changed rule', () {
    expect(LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.error)), isTrue);
    expect(LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.info)), isFalse);
    expect(
        LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.info, changed: true)),
        isTrue);
  });
}
```

- [ ] **Step 2: Run it — FAIL.**

- [ ] **Step 3: Implement**

In `layerx_log_store.dart` (import `layerx_log_level.dart` is already present), add below `errorCount`:

```dart
  /// Whether [log] is something a tester would report: an error, fatal,
  /// warning, or an API response that changed shape.
  static bool isProblemEntry(LayerXLogEntry log) =>
      log.level == LayerXLogLevel.error ||
      log.level == LayerXLogLevel.fatal ||
      log.level == LayerXLogLevel.warning ||
      log.responseChanged;

  /// The single source of truth for "how many problems are open" — used by the
  /// FAB badge, the header count, and the settings tile.
  static int get openProblemCount => logs.where(isProblemEntry).length;
```

In `lx_ui_kit.dart`, change `isProblem` to delegate (add the store import):

```dart
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
```

```dart
  static bool isProblem(LayerXLogEntry e) => LayerXLogStore.isProblemEntry(e);
```

- [ ] **Step 4: PASS + full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/repository/layerx_log_store.dart lib/src/mvvm/view/shell/lx_ui_kit.dart test/logging/open_problem_count_test.dart
git commit -m "feat(viewer): openProblemCount as the single problem-count source of truth"
```

---

### Task T1: Fix the AVG LATENCY card

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_dashboard_pane.dart` (line 176)
- Test: `test/widgets/dashboard_latency_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/dashboard_latency_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_dashboard_pane.dart';

LayerXLogEntry _net(String id, int ms) => LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026),
      level: LayerXLogLevel.success, source: LayerXLogSource.network,
      message: 'GET ok', endpoint: 'https://x/$id', statusCode: 200,
      journey: const [], extras: {'duration_ms': ms},
    );

void main() {
  testWidgets('AVG LATENCY shows the number with data present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LxDashboardPane(logs: [_net('a', 100), _net('b', 300)], onInspect: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('200ms'), findsOneWidget); // (100+300)/2
    expect(find.text('ms'), findsNothing); // never the bare literal
  });
}
```

- [ ] **Step 2: Run it — FAIL (finds bare 'ms', no '200ms').**

- [ ] **Step 3: Implement** — in `_metricsGrid`, change:

```dart
      _Metric('AVG LATENCY', avgLatency == 0 ? '—' : 'ms', LxTheme.accent),
```

to:

```dart
      _Metric('AVG LATENCY', avgLatency == 0 ? '—' : '${avgLatency}ms',
          LxTheme.accent),
```

- [ ] **Step 4: PASS + full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_dashboard_pane.dart test/widgets/dashboard_latency_test.dart
git commit -m "fix(viewer): AVG LATENCY card rendered the literal 'ms' with no number"
```

---

### Task T2: Route every copy through `LxCopy`

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_inspector_pane.dart` (payload copy `:304`, stack copy `:269`, remove local `_copy`)
- Modify: `lib/src/mvvm/view/shell/lx_console_pane.dart` (row copy `:244-246`)
- Modify: `lib/src/mvvm/view/shell/lx_debugger_shell.dart` (export-all `:206-210`)
- Modify: `lib/src/widgets/lx_fab_trigger.dart` ("Export & Copy All" `:278-283`)
- Test: `test/widgets/unified_copy_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/unified_copy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';

void main() {
  testWidgets('the Inspector payload Copy is no longer silent', (tester) async {
    final e = LayerXLogEntry(
      id: 'x', dedupKey: 'x', timestamp: DateTime(2026),
      level: LayerXLogLevel.error, source: LayerXLogSource.server,
      category: LayerXLogCategory.api, message: 'API Error',
      endpoint: 'https://x/y', statusCode: 500,
      responsePayload: '{"error":true}', journey: const [], extras: const {},
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LxInspectorPane(log: e))));
    await tester.tap(find.text('Response'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text(LxCopy.confirmation), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it — FAIL (no snackbar appears).**

- [ ] **Step 3: Implement.** In each file add `import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';` (path-adjusted) and:

1. `lx_inspector_pane.dart` — payload copy becomes:
```dart
            onPressed: () => LxCopy.copy(context, body),
```
   Stack copy `onTap` becomes `() => LxCopy.copy(context, stack)`. Delete the now-unused `_copy` method (and the `LxTheme.snackBar` usage it held). Keep the `services.dart` import only if still needed (SelectableText doesn't need it; remove if unused).
2. `lx_console_pane.dart` — row copy `onTap` body becomes:
```dart
                LxCopy.copy(context, LxKit.copySummary(e));
```
   (remove the manual `Clipboard.setData` + snackbar lines; drop the `services.dart` import if now unused).
3. `lx_debugger_shell.dart` — the export-all `onPressed` becomes:
```dart
          onPressed: () => LxCopy.copyExport(context),
```
   (remove the local messenger/snackbar lines).
4. `lx_fab_trigger.dart` — "Export & Copy All" `onTap` becomes:
```dart
                onTap: () {
                  Navigator.pop(ctx);
                  LxCopy.copyExport(context);
                },
```

- [ ] **Step 4: PASS + full suite + analyze.** Existing tests asserting old wordings (e.g. `console_row_copy_test.dart` asserts clipboard content, fine) must stay green; if any test asserts an old snackbar STRING, update that test to `LxCopy.confirmation` — the unified wording is the spec.

- [ ] **Step 5: Commit**

```bash
git add -A lib/src/mvvm/view/shell/ lib/src/widgets/lx_fab_trigger.dart test/widgets/unified_copy_test.dart
git commit -m "feat(viewer): every copy action routes through LxCopy with one wording"
```

---

### Task T3: Remove one-tap destructive clears

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_debugger_shell.dart` (delete the trash `IconButton`)
- Modify: `lib/src/widgets/lx_fab_trigger.dart` (delete the "Clear All Logs" tile)
- Test: `test/widgets/no_one_tap_clear_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/no_one_tap_clear_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  testWidgets('the shell app bar has no one-tap clear icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
  });
}
```

- [ ] **Step 2: Run it — FAIL (icon present).**

- [ ] **Step 3: Implement.** Delete the entire trash `IconButton` from the shell's `actions:` and the entire `_menuTile(... 'Clear All Logs' ...)` block from the FAB quick menu (and its now-unused imports if any).

- [ ] **Step 4: PASS + full suite + analyze.** If `viewer_test.dart`/others reference the removed control, update them — removal is the spec.

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_debugger_shell.dart lib/src/widgets/lx_fab_trigger.dart test/widgets/no_one_tap_clear_test.dart
git commit -m "feat(viewer): remove one-tap destructive clear from app bar and FAB menu"
```

---

### Task T4: Guarded "Start a new session" with copy-first and Undo

**Files:**
- Modify: `lib/src/repository/layerx_log_store.dart` (add `restore`)
- Modify: `lib/src/mvvm/view/shell/lx_debugger_shell.dart` (overflow `⋯` menu + confirm sheet + undo snackbar)
- Test: `test/widgets/new_session_flow_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/new_session_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry _e(String id) => LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026),
      level: LayerXLogLevel.error, source: LayerXLogSource.app,
      category: LayerXLogCategory.app, message: id,
      journey: const [], extras: const {},
    );

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  testWidgets('clearing requires the confirm sheet and Undo restores',
      (tester) async {
    LayerXLogStore.add(_e('boom-1'));
    LayerXLogStore.add(_e('boom-2'));
    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    // Open the overflow menu and pick "Start a new session".
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start a new session'));
    await tester.pump(const Duration(milliseconds: 400));

    // The sheet explains the stakes with the live count.
    expect(find.textContaining('clears all 2'), findsOneWidget);
    expect(find.text('Copy report first'), findsOneWidget);

    // Confirm the clear.
    await tester.tap(find.text('Clear'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(LayerXLogStore.logs, isEmpty);

    // Undo restores both entries.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(LayerXLogStore.logs.length, 2);
  });
}
```

- [ ] **Step 2: Run it — FAIL (no more_vert menu).**

- [ ] **Step 3: Implement.**

Store — add below `clear()`:

```dart
  /// Restores a previously captured snapshot (used by the clear-session Undo).
  static void restore(List<LayerXLogEntry> entries) {
    logsNotifier.value = List<LayerXLogEntry>.from(entries);
  }
```

Shell — add to `actions:` (after the export button) a `PopupMenuButton`:

```dart
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          color: LxTheme.surfaceHigh,
          onSelected: (v) {
            if (v == 'new-session') _confirmNewSession(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'new-session', child: Text('Start a new session')),
          ],
        ),
```

And add the flow methods to the state class:

```dart
  void _confirmNewSession(BuildContext context) {
    final count = LayerXLogStore.logs.length;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LxTheme.surfaceAlt,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start a new session?',
                  style: LxTheme.bodyPrimary
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "This clears all $count captured problems and can't be undone "
                'after this snackbar disappears.',
                style: LxTheme.bodySecondary,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  LxCopy.copyExport(context);
                },
                child: const Text('Copy report first'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearWithUndo(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearWithUndo(BuildContext context) {
    final snapshot = List<LayerXLogEntry>.from(LayerXLogStore.logs);
    LayerXLogStore.clear();
    LayerXViewerState.selected.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Session cleared'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => LayerXLogStore.restore(snapshot),
        ),
      ));
  }
```

(Add the `lx_copy.dart` import; `LayerXViewerState` is already imported.)

- [ ] **Step 4: PASS + full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/repository/layerx_log_store.dart lib/src/mvvm/view/shell/lx_debugger_shell.dart test/widgets/new_session_flow_test.dart
git commit -m "feat(viewer): guarded 'Start a new session' with copy-first and Undo"
```

---

### Task T5: Release 1.5.0

**Files:** `pubspec.yaml`, `CHANGELOG.md`

- [ ] **Step 1:** `version: 1.4.2` → `version: 1.5.0`.
- [ ] **Step 2:** CHANGELOG entry above `## 1.4.2`:

```markdown
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
```

- [ ] **Step 3:** `flutter test test/ && dart analyze lib/ test/ bin/ && rm -rf example/build && flutter pub publish --dry-run` — all green, 0 warnings.
- [ ] **Step 4:** Commit `chore(viewer): release 1.5.0 — UX P0 quick wins`, publish `--force`, merge `feat/ux-p0` → `dev-umair`, push.

---

## Self-Review

- **Spec coverage vs roadmap P0:** groundwork formatter (G1), LxCopy + queue fix (G2), openProblemCount (G3), remove one-tap clears (T3), guarded new-session + Undo (T4), AVG LATENCY (T1), unified copy incl. silent Inspector (T2), empty-export guard (G2/T2), release (T5). All five roadmap tasks + all three groundwork tasks mapped. `openProblemCount` consumers (FAB badge/header/settings) rewire in **P1** per the roadmap — G3 only creates the source of truth.
- **Placeholders:** none; each step has complete code.
- **Type consistency:** `LxCopy.copy/copyExport/confirmation`, `LayerXReportFormatter.formatIssue/relativeTime`, `LayerXLogStore.isProblemEntry/openProblemCount/restore` used consistently.
