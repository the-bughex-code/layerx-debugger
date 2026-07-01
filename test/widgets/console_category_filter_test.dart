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

    expect(find.text('an app log'), findsOneWidget);
    expect(find.text('a ui overflow'), findsOneWidget);

    await tester.tap(find.text('UI Exceptions'));
    await tester.pumpAndSettle();
    expect(find.text('an app log'), findsNothing);
    expect(find.text('a ui overflow'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('an app log'), findsOneWidget);
  });
}
