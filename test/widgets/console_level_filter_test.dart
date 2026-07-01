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

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR').last);
    await tester.pumpAndSettle();

    expect(find.text('just info'), findsNothing);
    expect(find.text('an error row'), findsOneWidget);
  });
}
