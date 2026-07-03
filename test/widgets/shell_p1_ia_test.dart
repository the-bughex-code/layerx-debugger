import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry _entry(String id,
        {LayerXLogLevel level = LayerXLogLevel.error}) =>
    LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026, 1, 1, 10),
      level: level, source: LayerXLogSource.app,
      category: LayerXLogCategory.app, message: id,
      journey: const [], extras: const {},
    );

/// Delivers [total] as a run of small discrete frames rather than one jump.
///
/// A single large `pump(Duration)` can leave a route transition (a pushed
/// detail route, the overflow `PopupMenuButton`'s route) mid-composite: the
/// animation clock advances past the end, yet the last frame's layer tree
/// isn't repainted, so hit-testing still sees the route's barrier on top of
/// the content. Stepping through smaller frames lets each transition actually
/// reach and paint its terminal frame.
Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  testWidgets('opening the shell lands on Problems with no nav tabs',
      (tester) async {
    LayerXLogStore.add(_entry('boom happens'));
    LayerXLogStore.add(_entry('just info', level: LayerXLogLevel.info));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    // The problem is visible with zero taps…
    expect(find.text('boom happens'), findsOneWidget);
    // …the info row is not (it lives behind Everything)…
    expect(find.text('just info'), findsNothing);
    // …and the old 4-destination nav labels are gone entirely.
    for (final label in ['Dashboard', 'Inspector', 'dashboard', 'inspector']) {
      expect(find.text(label), findsNothing,
          reason: "old nav label '$label' should not render");
    }

    // UX P3 Task B: the header is plain — a "Debugger" title and an honest
    // problem count, no shell-prompt cosplay.
    expect(find.text('Debugger'), findsOneWidget);
    expect(find.textContaining('problems'), findsOneWidget);
    expect(find.textContaining('@dbg'), findsNothing);
  });

  testWidgets('Everything shows the Console pane; Problems returns',
      (tester) async {
    LayerXLogStore.add(_entry('segment error row'));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Everything'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    expect(find.text('search logs…'), findsOneWidget);

    await tester.tap(find.text('Problems'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    expect(find.text('segment error row'), findsOneWidget);
    expect(find.text('search logs…'), findsNothing);
  });

  testWidgets('tapping a problem row pushes a Details screen; back returns',
      (tester) async {
    LayerXLogStore.add(_entry('boom happens'));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('boom happens'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('boom happens'), findsWidgets);

    await tester.tap(find.byType(BackButton));
    // The back arrow pops via Navigator.maybePop, whose willPop check awaits a
    // microtask — a zero-duration pump flushes it before the transition pumps.
    await tester.pump();
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('Details'), findsNothing);
    expect(find.text('boom happens'), findsOneWidget);
  });

  testWidgets("'Done' pops the shell back to the host app", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const LxDebuggerShell()),
              ),
              child: const Text('open debugger'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open debugger'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    // 'Done' pops via Navigator.maybePop, whose willPop check awaits a
    // microtask — a zero-duration pump flushes it before the transition pumps.
    await tester.pump();
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('Done'), findsNothing);
    expect(find.text('open debugger'), findsOneWidget);
  });

  testWidgets('pause and resume live updates via the overflow menu',
      (tester) async {
    LayerXLogStore.add(_entry('first problem'));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('first problem'), findsOneWidget);

    // The app-bar pause icon is gone — pausing lives in the ⋯ menu now.
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Pause live updates'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    LayerXLogStore.add(_entry('second problem'));
    await tester.pump();
    expect(find.text('second problem'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Resume live updates'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('second problem'), findsOneWidget);
  });
}
