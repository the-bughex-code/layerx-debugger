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

    expect(find.text('UI Exceptions'), findsWidgets);
    expect(find.text('lib/home.dart:42'), findsOneWidget);

    expect(find.text('STACK TRACE'), findsOneWidget);
    expect(find.textContaining('#0 Home.build'), findsNothing);

    await tester.tap(find.text('STACK TRACE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#0 Home.build'), findsOneWidget);
  });
}
