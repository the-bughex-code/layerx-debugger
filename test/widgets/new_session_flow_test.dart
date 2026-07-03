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

/// Delivers [total] as a run of small discrete frames rather than one jump.
///
/// A single large `pump(Duration)` can leave a route transition (the
/// overflow `PopupMenuButton`'s route, the confirm bottom sheet)
/// mid-composite: the animation clock advances past the end, yet the last
/// frame's layer tree isn't repainted, so hit-testing still sees the route's
/// barrier on top of the content. Stepping through smaller frames lets each
/// transition actually reach and paint its terminal frame.
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

  testWidgets('clearing requires the confirm sheet and Undo restores',
      (tester) async {
    LayerXLogStore.add(_e('boom-1'));
    LayerXLogStore.add(_e('boom-2'));
    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    // Open the overflow menu and pick "Start a new session".
    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Start a new session'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    // The sheet explains the stakes with the live count.
    expect(find.textContaining('clears all 2'), findsOneWidget);
    expect(find.text('Copy report first'), findsOneWidget);

    // Confirm the clear.
    await tester.tap(find.text('Clear'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    expect(LayerXLogStore.logs, isEmpty);

    // Undo restores both entries.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(LayerXLogStore.logs.length, 2);
  });
}
