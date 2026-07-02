import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_everything_pane.dart';

LayerXLogEntry _mk({
  required String id,
  required LayerXLogLevel level,
  DateTime? timestamp,
  String? endpoint,
  Map<String, dynamic>? extras,
}) =>
    LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: timestamp ?? DateTime(2026, 1, 1, 10, 0, 0),
      level: level,
      source: LayerXLogSource.app,
      category: LayerXLogCategory.app,
      message: id,
      endpoint: endpoint,
      journey: const [],
      extras: extras ?? const {},
    );

void main() {
  group('LxEverythingPane widget', () {
    testWidgets('defaults to the Console sub-pane', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxEverythingPane(
              logs: [_mk(id: 'a log line', level: LayerXLogLevel.info)],
              onInspect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('search logs…'), findsOneWidget);
    });

    testWidgets(
        'switching to Network shows the network search hint; switching to '
        'Dashboard with an error present shows RECENT ISSUES', (tester) async {
      final error = _mk(
        id: 'an error occurred',
        level: LayerXLogLevel.error,
        endpoint: '/api/things',
        extras: const {'duration_ms': 120},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxEverythingPane(
              logs: [error],
              onInspect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Network'));
      await tester.pump();

      expect(find.text('filter endpoints…'), findsOneWidget);

      await tester.tap(find.text('Dashboard'));
      await tester.pump();

      expect(find.text('RECENT ISSUES'), findsOneWidget);
    });
  });
}
