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

    await tester.tap(find.text('console'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('first row'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    LayerXLogStore.add(mkEntry('second row'));
    await tester.pump();
    expect(find.text('second row'), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.text('second row'), findsOneWidget);
  });
}
