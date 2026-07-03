import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry _entry(String id,
        {LayerXLogLevel level = LayerXLogLevel.error, DateTime? timestamp}) =>
    LayerXLogEntry(
      id: id, dedupKey: id, timestamp: timestamp ?? DateTime(2026, 1, 1, 10),
      level: level, source: LayerXLogSource.app,
      category: LayerXLogCategory.app, message: id,
      journey: const [], extras: const {},
    );

/// Delivers [total] as a run of small discrete frames rather than one jump.
///
/// A single large `pump(Duration)` can leave a route transition (a pushed
/// detail route, a snackbar) mid-composite: the animation clock advances past
/// the end, yet the last frame's layer tree isn't repainted, so hit-testing
/// still sees the route's barrier on top of the content. Stepping through
/// smaller frames lets each transition actually reach and paint its terminal
/// frame.
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

  testWidgets(
      'Copy bug report is visible on a pushed problem and copying shows the '
      'confirmation snackbar', (tester) async {
    // Clipboard.setData hits a real platform channel; without a mock
    // handler the await inside LxCopy.copy never resolves and the
    // confirmation snackbar never shows.
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    LayerXLogStore.add(_entry('first problem',
        timestamp: DateTime(2026, 1, 1, 10, 0, 1)));
    LayerXLogStore.add(_entry('second problem',
        timestamp: DateTime(2026, 1, 1, 10, 0, 0)));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('first problem'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('Copy bug report'), findsOneWidget);

    await tester.tap(find.text('Copy bug report'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.textContaining('Copied'), findsOneWidget);
  });

  testWidgets(
      'Next walks to the second problem and shows "2 of 2"; Prev returns and '
      'is disabled at index 0', (tester) async {
    LayerXLogStore.add(_entry('first problem',
        timestamp: DateTime(2026, 1, 1, 10, 0, 1)));
    LayerXLogStore.add(_entry('second problem',
        timestamp: DateTime(2026, 1, 1, 10, 0, 0)));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('first problem'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.textContaining('1 of 2'), findsOneWidget);

    // Prev is disabled at the start of the list.
    final prevButton = tester.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_left));
    expect(prevButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.textContaining('second problem'), findsWidgets);
    expect(find.textContaining('2 of 2'), findsOneWidget);

    // Next is now disabled at the end of the list.
    final nextButton = tester.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_right));
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.textContaining('first problem'), findsWidgets);
    expect(find.textContaining('1 of 2'), findsOneWidget);
  });

  testWidgets(
      'a non-problem row opened from Everything pushes a single-entry list '
      'with both chevrons disabled and no "of N" suffix', (tester) async {
    LayerXLogStore.add(
        _entry('an info row only', level: LayerXLogLevel.info));

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Everything'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    await tester.tap(find.text('an info row only'));
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('of 1'), findsNothing);

    final prevButton = tester.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_left));
    final nextButton = tester.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_right));
    expect(prevButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });
}
