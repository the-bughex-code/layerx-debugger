# Viewer Overhaul — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add category filter, level filter, pause/resume, per-row copy, and Inspector category/location + collapsible stack trace to the Neo Terminal viewer, surfacing the Phase-1 data.

**Architecture:** Internal viewer widgets only (no public API). Follow the existing `LxTheme` / `LxKit` / chip patterns. State is local to each pane except pause, which lives on the shell and freezes the snapshot passed down.

**Tech Stack:** Flutter, `flutter_test` (VM widget tests).

---

## Conventions

- Run tests with `flutter test <path>` (VM). If it errors with "Failed to find … flutter_tester", run `flutter precache --force --universal` once, then re-run.
- `dart analyze lib/ test/` must be clean before each commit. Viewer files start with `// ignore_for_file: public_member_api_docs`, so internal members don't need doc comments.
- Running tests may modify `example/pubspec.lock`; never stage it.
- TDD: write the failing widget test, watch it fail, implement minimally, watch it pass, commit.

## Shared test helper

Every widget test seeds `LayerXLogStore` and builds entries. Use this entry factory inside each test file (copy it in — tests may run out of order):

```dart
LayerXLogEntry mkEntry({
  required String message,
  LayerXLogCategory category = LayerXLogCategory.app,
  LayerXLogLevel level = LayerXLogLevel.info,
  LayerXLogSource source = LayerXLogSource.app,
  String? sourceFile,
  int? sourceLine,
  String? stackTrace,
  String? endpoint,
}) =>
    LayerXLogEntry(
      id: message,
      dedupKey: message,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: level,
      source: source,
      category: category,
      message: message,
      sourceFile: sourceFile,
      sourceLine: sourceLine,
      stackTrace: stackTrace,
      endpoint: endpoint,
      journey: const [],
      extras: const {},
    );
```

---

### Task 1: Inspector — category, location, collapsible stack trace

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_inspector_pane.dart`
- Test: `test/widgets/inspector_phase2_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/inspector_phase2_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';

LayerXLogEntry mkEntry({
  required String message,
  LayerXLogCategory category = LayerXLogCategory.app,
  LayerXLogLevel level = LayerXLogLevel.info,
  LayerXLogSource source = LayerXLogSource.app,
  String? sourceFile,
  int? sourceLine,
  String? stackTrace,
  String? endpoint,
}) =>
    LayerXLogEntry(
      id: message, dedupKey: message,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: level, source: source, category: category, message: message,
      sourceFile: sourceFile, sourceLine: sourceLine, stackTrace: stackTrace,
      endpoint: endpoint, journey: const [], extras: const {},
    );

void main() {
  testWidgets('shows category + location and a collapsed stack that expands',
      (tester) async {
    final e = mkEntry(
      message: 'Boom happened',
      category: LayerXLogCategory.uiException,
      level: LayerXLogLevel.error,
      sourceFile: 'lib/home.dart',
      sourceLine: 42,
      stackTrace: '#0 Home.build (lib/home.dart:42:5)\n#1 main (lib/main.dart:3:3)',
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LxInspectorPane(log: e))));

    // Category label + location are shown in the details.
    expect(find.text('UI Exceptions'), findsWidgets);
    expect(find.text('lib/home.dart:42'), findsOneWidget);

    // Stack header is present, but the trace is collapsed (not rendered yet).
    expect(find.text('STACK TRACE'), findsOneWidget);
    expect(find.textContaining('#0 Home.build'), findsNothing);

    // Tapping the header expands it.
    await tester.tap(find.text('STACK TRACE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#0 Home.build'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, confirm it FAILS**

Run: `flutter test test/widgets/inspector_phase2_test.dart`
Expected: FAIL — no 'UI Exceptions'/'STACK TRACE' text yet.

- [ ] **Step 3: Implement** — edit `lib/src/mvvm/view/shell/lx_inspector_pane.dart`.

Add a collapse state field to `_LxInspectorPaneState` (next to `int _tab = 0;`):

```dart
  bool _stackOpen = false;
```

Reset it when the selected entry changes — in `didUpdateWidget`, change the body to:

```dart
    if (old.log?.id != widget.log?.id) {
      _tab = 0;
      _stackOpen = false;
    }
```

In `_overview`, add Category to the DETAILS block right after the `_kv('Source', e.source.name),` line:

```dart
        _kv('Category', e.category.label),
```

Add Location right after the `_kv('Level', e.level.label),` line:

```dart
        if (e.sourceFile != null)
          _kv('Location', '${e.sourceFile}:${e.sourceLine ?? '?'}'),
```

At the END of the `_overview` ListView children (after the occurrences `_kv`), add the stack section:

```dart
        if (e.stackTrace != null) ...[
          const SizedBox(height: 14),
          _stackSection(context, e.stackTrace!),
        ],
```

Add these two methods to the state class:

```dart
  Widget _stackSection(BuildContext context, String stack) {
    return Container(
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LxTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _stackOpen = !_stackOpen),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(_stackOpen ? Icons.expand_more : Icons.chevron_right,
                      size: 18, color: LxTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text('STACK TRACE', style: LxTheme.sectionLabel),
                  const Spacer(),
                  if (_stackOpen)
                    GestureDetector(
                      onTap: () => _copy(context, stack, 'Stack trace copied ✓'),
                      child: const Icon(Icons.copy,
                          size: 14, color: LxTheme.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          if (_stackOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: SelectableText(stack,
                  style: LxTheme.mono.copyWith(fontSize: 11, height: 1.5)),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(LxTheme.snackBar(toast));
  }
```

(`Clipboard`/`ClipboardData` come from `package:flutter/services.dart`, already imported in this file.)

- [ ] **Step 4: Run the test — confirm PASS. Then run the full suite `flutter test test/` and `dart analyze lib/ test/`.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_inspector_pane.dart test/widgets/inspector_phase2_test.dart
git commit -m "feat(viewer): show category + location and a collapsible stack trace in the Inspector"
```

---

### Task 2: Console — category filter chips

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_console_pane.dart`
- Test: `test/widgets/console_category_filter_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/console_category_filter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';

LayerXLogEntry mkEntry({
  required String message,
  LayerXLogCategory category = LayerXLogCategory.app,
}) =>
    LayerXLogEntry(
      id: message, dedupKey: message,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: LayerXLogLevel.info, source: LayerXLogSource.app,
      category: category, message: message,
      journey: const [], extras: const {},
    );

void main() {
  testWidgets('category chip filters rows to that category', (tester) async {
    final logs = [
      mkEntry(message: 'an app log', category: LayerXLogCategory.app),
      mkEntry(message: 'a ui overflow', category: LayerXLogCategory.uiException),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LxConsolePane(logs: logs, onInspect: (_) {}))));

    // Both visible initially.
    expect(find.text('an app log'), findsOneWidget);
    expect(find.text('a ui overflow'), findsOneWidget);

    // Tap the "UI Exceptions" category chip → only the UI row remains.
    await tester.tap(find.text('UI Exceptions'));
    await tester.pumpAndSettle();
    expect(find.text('an app log'), findsNothing);
    expect(find.text('a ui overflow'), findsOneWidget);

    // "All" restores both.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('an app log'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, confirm it FAILS** (no 'UI Exceptions' chip yet — the pane shows source chips).

- [ ] **Step 3: Implement** — edit `lib/src/mvvm/view/shell/lx_console_pane.dart`.

Add the import:

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

Replace the state field `LayerXLogSource? _source;` with:

```dart
  LayerXLogCategory? _category;
```

In `build`, replace the source filter line `if (_source != null && e.source != _source) return false;` with:

```dart
      if (_category != null && e.category != _category) return false;
```

In `build`, replace the `_sourceChips(),` call with `_categoryChips(),`.

Delete the entire `_sourceChips()` method and add `_categoryChips()`:

```dart
  Widget _categoryChips() {
    final present = <LayerXLogCategory>{for (final e in widget.logs) e.category};
    final ordered =
        LayerXLogCategory.values.where(present.contains).toList();

    Widget chip(String label, LayerXLogCategory? c, Color color) {
      final active = _category == c;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _category = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      active ? color.withValues(alpha: 0.45) : Colors.transparent),
            ),
            child: Text(label,
                style: LxTheme.monoSm.copyWith(
                    color: active ? color : LxTheme.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null, LxTheme.textPrimary),
          for (final c in ordered) chip(c.label, c, c.color),
        ],
      ),
    );
  }
```

(`LayerXLogSource` is still imported and used in `_logRow`'s meta — leave that import.)

- [ ] **Step 4: Run the test — confirm PASS. Then full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_console_pane.dart test/widgets/console_category_filter_test.dart
git commit -m "feat(viewer): filter the console by log category"
```

---

### Task 3: Console — level filter

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_console_pane.dart`
- Test: `test/widgets/console_level_filter_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/console_level_filter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';

LayerXLogEntry mkEntry({required String message, required LayerXLogLevel level}) =>
    LayerXLogEntry(
      id: message, dedupKey: message,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: level, source: LayerXLogSource.app,
      category: LayerXLogCategory.app, message: message,
      journey: const [], extras: const {},
    );

void main() {
  testWidgets('level filter narrows rows to the chosen level', (tester) async {
    final logs = [
      mkEntry(message: 'just info', level: LayerXLogLevel.info),
      mkEntry(message: 'an error row', level: LayerXLogLevel.error),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LxConsolePane(logs: logs, onInspect: (_) {}))));

    expect(find.text('just info'), findsOneWidget);
    expect(find.text('an error row'), findsOneWidget);

    // Open the level menu (funnel) and pick ERROR.
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR').last);
    await tester.pumpAndSettle();

    expect(find.text('just info'), findsNothing);
    expect(find.text('an error row'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, confirm it FAILS** (no funnel icon yet).

- [ ] **Step 3: Implement** — edit `lib/src/mvvm/view/shell/lx_console_pane.dart`.

Add the import (needed for the menu items):

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
```

Add the state field near `_category`:

```dart
  LayerXLogLevel? _level;
```

In `build`, add a level check inside the `.where` predicate, right after the category check:

```dart
      if (_level != null && e.level != _level) return false;
```

Change `_searchField()` so it returns a Row with the search box plus the level menu. Replace the whole `_searchField()` method with:

```dart
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: LxTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LxTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: LxTheme.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: LxTheme.mono.copyWith(fontSize: 12),
                      cursorColor: LxTheme.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: 'search logs…',
                        hintStyle:
                            LxTheme.monoSm.copyWith(color: LxTheme.textDim),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _levelMenu(),
        ],
      ),
    );
  }

  Widget _levelMenu() {
    return Container(
      height: 38,
      width: 42,
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _level == null ? LxTheme.border : LxTheme.accent),
      ),
      child: PopupMenuButton<LayerXLogLevel?>(
        tooltip: 'Filter by level',
        icon: Icon(Icons.filter_list,
            size: 18,
            color: _level == null ? LxTheme.textSecondary : LxTheme.accent),
        color: LxTheme.surfaceHigh,
        onSelected: (v) => setState(() => _level = v),
        itemBuilder: (_) => [
          const PopupMenuItem<LayerXLogLevel?>(
              value: null, child: Text('All levels')),
          for (final l in LayerXLogLevel.values)
            PopupMenuItem<LayerXLogLevel?>(
              value: l,
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: l.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(l.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run the test — confirm PASS. Then full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_console_pane.dart test/widgets/console_level_filter_test.dart
git commit -m "feat(viewer): filter the console by log level"
```

---

### Task 4: Console — per-row copy

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_ui_kit.dart` (add `copySummary`)
- Modify: `lib/src/mvvm/view/shell/lx_console_pane.dart`
- Test: `test/widgets/console_row_copy_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/console_row_copy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';

void main() {
  testWidgets('row copy button copies a summary and does not inspect',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    var inspected = false;
    final e = LayerXLogEntry(
      id: 'x', dedupKey: 'x', timestamp: DateTime(2026, 1, 1, 9, 8, 7),
      level: LayerXLogLevel.error, source: LayerXLogSource.app,
      category: LayerXLogCategory.uiException, message: 'copy me',
      sourceFile: 'lib/a.dart', sourceLine: 12, journey: const [], extras: const {},
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LxConsolePane(logs: [e], onInspect: (_) => inspected = true))));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(inspected, isFalse);
    expect(calls, hasLength(1));
    expect(calls.first.arguments['text'], contains('copy me'));
    expect(calls.first.arguments['text'], contains('lib/a.dart:12'));
  });
}
```

- [ ] **Step 2: Run it, confirm it FAILS** (no copy icon in rows yet).

- [ ] **Step 3: Implement.**

In `lib/src/mvvm/view/shell/lx_ui_kit.dart`, add this static method inside `LxKit` (after `clockTime`):

```dart
  /// A one-line, copyable summary of an entry for the per-row copy action.
  static String copySummary(LayerXLogEntry e) {
    final loc = e.sourceFile != null ? ' (${e.sourceFile}:${e.sourceLine ?? '?'})' : '';
    return '[${clockTime(e.timestamp)}] [${e.level.label}] '
        '[${e.category.label}] ${e.message}$loc';
  }
```

Add the imports it needs at the top of `lx_ui_kit.dart` if not present (`layerx_log_category` — `layerx_log_entry` and `layerx_log_level` are already imported):

```dart
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
```

In `lib/src/mvvm/view/shell/lx_console_pane.dart`, add the services import for the clipboard:

```dart
import 'package:flutter/services.dart';
```

In `_logRow`, add a trailing copy button. Change the `Expanded(child: Column(...))` block so the row ends with the copy icon — insert this widget as the LAST child of the row's `children:` list (after the `Expanded(...)`):

```dart
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Clipboard.setData(ClipboardData(text: LxKit.copySummary(e)));
                ScaffoldMessenger.of(context)
                    .showSnackBar(LxTheme.snackBar('Log copied ✓'));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.copy, size: 14, color: LxTheme.textDim),
              ),
            ),
```

The `GestureDetector` with `HitTestBehavior.opaque` absorbs the tap so the row's `InkWell` (which calls `onInspect`) does not also fire.

- [ ] **Step 4: Run the test — confirm PASS. Then full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_ui_kit.dart lib/src/mvvm/view/shell/lx_console_pane.dart test/widgets/console_row_copy_test.dart
git commit -m "feat(viewer): copy a single log row to the clipboard"
```

---

### Task 5: Shell — pause / resume live logs

**Files:**
- Modify: `lib/src/mvvm/view/shell/lx_debugger_shell.dart`
- Test: `test/widgets/shell_pause_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/shell_pause_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry mkEntry(String message) => LayerXLogEntry(
      id: message, dedupKey: message,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: LayerXLogLevel.info, source: LayerXLogSource.app,
      category: LayerXLogCategory.app, message: message,
      journey: const [], extras: const {},
    );

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  testWidgets('pausing freezes the displayed logs until resumed',
      (tester) async {
    LayerXLogStore.add(mkEntry('first row'));
    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));

    // Go to the Console tab.
    await tester.tap(find.text('Console'));
    await tester.pumpAndSettle();
    expect(find.text('first row'), findsOneWidget);

    // Pause, then add a new log — it must NOT appear.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    LayerXLogStore.add(mkEntry('second row'));
    await tester.pump();
    expect(find.text('second row'), findsNothing);

    // Resume — the new log appears.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.text('second row'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, confirm it FAILS** (no pause icon).

- [ ] **Step 3: Implement** — edit `lib/src/mvvm/view/shell/lx_debugger_shell.dart`.

Add state fields to `_LxDebuggerShellState` (next to `int _index = 0;`):

```dart
  bool _paused = false;
  List<LayerXLogEntry>? _frozen;
```

In `build`, inside the `ValueListenableBuilder` builder, the first line is
`builder: (context, logs, _) {`. Immediately after it, derive the displayed list
and use it everywhere `logs` currently feeds the panes/counters:

```dart
          final displayLogs = _paused ? (_frozen ?? logs) : logs;
```

Then change the three pane constructions and the two counters to use
`displayLogs` instead of `logs`:
- `errors` computation: `final errors = displayLogs.where(...)`
- `networkCount`: `final networkCount = displayLogs.where(...)`
- `LxDashboardPane(logs: displayLogs, ...)`, `LxNetworkPane(logs: displayLogs, ...)`, `LxConsolePane(logs: displayLogs, ...)`
- The app bar total: `_appBar(context, displayLogs.length, errors)`

Leave the `LayerXLogStore.logsNotifier` valueListenable as-is (so resume picks up
everything that accumulated).

Add a pause/resume action to `_appBar`. In `_appBar`'s `actions: [ ... ]` list,
add this as the FIRST action (before the export button):

```dart
        IconButton(
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 20,
              color: _paused ? LxTheme.accentAmber : LxTheme.textSecondary),
          tooltip: _paused ? 'Resume live logs' : 'Pause live logs',
          onPressed: () => setState(() {
            _paused = !_paused;
            _frozen = _paused
                ? List<LayerXLogEntry>.from(LayerXLogStore.logs)
                : null;
          }),
        ),
```

- [ ] **Step 4: Run the test — confirm PASS. Then full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/mvvm/view/shell/lx_debugger_shell.dart test/widgets/shell_pause_test.dart
git commit -m "feat(viewer): pause/resume live logs from the header"
```

---

### Task 6: Version bump, CHANGELOG, verify, publish prep

**Files:**
- Modify: `pubspec.yaml`, `CHANGELOG.md`

- [ ] **Step 1: Bump the version** — in `pubspec.yaml` change `version: 1.3.0` to `version: 1.4.0`.

- [ ] **Step 2: Add the CHANGELOG entry** — insert at the top, above `## 1.3.0`:

```markdown
## 1.4.0

### Added

- **Viewer overhaul (Phase 2).** The in-app log viewer gains: filter by
  **category** and by **level** in the Console, **pause / resume** of live logs
  from the header, a **per-row copy** action, and — in the Inspector — the log's
  **category** and **source `file:line`** plus a **collapsible stack trace**.
  Internal UI only; no API changes.
```

- [ ] **Step 3: Full verification**

Run: `flutter test test/ && dart analyze lib/ test/`
Expected: all pass, analyze clean.

Run: `rm -rf example/build && flutter pub publish --dry-run`
Expected: validation passes (0 warnings, aside from any git-state note).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(viewer): bump to 1.4.0 for viewer overhaul (Phase 2)"
```

---

## Self-Review

- **Spec coverage:** category filter (Task 2), level filter (Task 3), pause/resume (Task 5), per-row copy (Task 4), Inspector category+location+collapsible stack (Task 1), version/CHANGELOG (Task 6). Native share is an explicit non-goal. All mapped.
- **Placeholders:** none — every step has complete code.
- **Type consistency:** `_category:LayerXLogCategory?`, `_level:LayerXLogLevel?`, `_paused/_frozen`, `_stackOpen`, `LxKit.copySummary(entry)`, and the `displayLogs` rename are used consistently across tasks. Test entry factories include all required `LayerXLogEntry` fields.
