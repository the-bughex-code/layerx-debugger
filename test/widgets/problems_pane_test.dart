import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_problems_pane.dart';

LayerXLogEntry _mk({
  required String id,
  required LayerXLogLevel level,
  required DateTime timestamp,
  bool responseChanged = false,
  int? durationMs,
  LayerXLogSource source = LayerXLogSource.app,
  int? statusCode,
}) =>
    LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: timestamp,
      level: level,
      source: source,
      category: LayerXLogCategory.app,
      message: id,
      journey: const [],
      extras: durationMs == null ? const {} : {'duration_ms': durationMs},
      responseChanged: responseChanged,
      statusCode: statusCode,
    );

void main() {
  group('LxProblemsPane.problemsOf', () {
    test('ranks worst-first with newest-first tie-breaking', () {
      final base = DateTime(2026, 1, 1, 10, 0, 0);

      final info = _mk(
        id: 'just info',
        level: LayerXLogLevel.info,
        timestamp: base,
      );
      final errorOlder = _mk(
        id: 'error older',
        level: LayerXLogLevel.error,
        timestamp: base.add(const Duration(minutes: 1)),
      );
      final errorNewer = _mk(
        id: 'error newer',
        level: LayerXLogLevel.error,
        timestamp: base.add(const Duration(minutes: 2)),
      );
      final warning = _mk(
        id: 'a warning',
        level: LayerXLogLevel.warning,
        timestamp: base.add(const Duration(minutes: 3)),
      );
      final changed = _mk(
        id: 'response changed',
        level: LayerXLogLevel.success,
        timestamp: base.add(const Duration(minutes: 4)),
        responseChanged: true,
      );
      final slow = _mk(
        id: 'slow success',
        level: LayerXLogLevel.success,
        timestamp: base.add(const Duration(minutes: 5)),
        durationMs: 900,
      );
      final fast = _mk(
        id: 'fast success',
        level: LayerXLogLevel.success,
        timestamp: base.add(const Duration(minutes: 6)),
        durationMs: 100,
      );

      // Seed order is deliberately scrambled so the function must sort, not
      // just preserve input order.
      final logs = [
        info,
        slow,
        fast,
        changed,
        warning,
        errorOlder,
        errorNewer,
      ];

      final result = LxProblemsPane.problemsOf(logs);

      expect(
        result.map((e) => e.id).toList(),
        [
          'error newer',
          'error older',
          'a warning',
          'response changed',
          'slow success',
        ],
      );
    });
  });

  group('LxProblemsPane widget', () {
    testWidgets('shows only the problem row and taps fire onInspect',
        (tester) async {
      final error = _mk(
        id: 'an error occurred',
        level: LayerXLogLevel.error,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      );
      final info = _mk(
        id: 'just informational',
        level: LayerXLogLevel.info,
        timestamp: DateTime(2026, 1, 1, 10, 0, 1),
      );

      LayerXLogEntry? inspected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [error, info],
              onInspect: (e) => inspected = e,
            ),
          ),
        ),
      );

      expect(find.text('an error occurred'), findsOneWidget);
      expect(find.text('just informational'), findsNothing);

      await tester.tap(find.text('an error occurred'));
      await tester.pump();

      expect(inspected, error);
    });

    testWidgets('slow success row shows the duration chip', (tester) async {
      final slow = _mk(
        id: 'this call took a while',
        level: LayerXLogLevel.success,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        durationMs: 900,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [slow],
              onInspect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('this call took a while'), findsOneWidget);
      expect(find.textContaining('900ms'), findsOneWidget);
    });

    testWidgets('empty state shows when there are no problems',
        (tester) async {
      final info = _mk(
        id: 'nothing wrong here',
        level: LayerXLogLevel.info,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [info],
              onInspect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('NO PROBLEMS YET'), findsOneWidget);
      // Scope-honest copy (UX P4): the tool records, it can't retry — one
      // shared line across Problems / Console / Network empty states.
      expect(
        find.text('Go use the app — anything that breaks shows up here. '
            'This records what happened — redo the action in the app.'),
        findsOneWidget,
      );
    });

    testWidgets('500-error card shows source label and a Backend verdict',
        (tester) async {
      final serverError = _mk(
        id: 'the server blew up',
        level: LayerXLogLevel.error,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        source: LayerXLogSource.server,
        statusCode: 500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [serverError],
              onInspect: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining(LayerXLogSource.server.label),
          findsOneWidget);
      expect(find.textContaining('Backend'), findsOneWidget);
    });

    testWidgets('info-level slow row shows no verdict but keeps the ⏱ chip',
        (tester) async {
      final slowInfo = _mk(
        id: 'a slow but healthy call',
        level: LayerXLogLevel.info,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        durationMs: 900,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [slowInfo],
              onInspect: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('900ms'), findsOneWidget);
      expect(find.textContaining('Backend'), findsNothing);
      expect(find.textContaining('Undetermined'), findsNothing);
    });

    testWidgets(
        'fatal entry renders exactly once alongside an error entry '
        '(sanity: card decoration did not duplicate the row)', (tester) async {
      final fatal = _mk(
        id: 'app crashed hard',
        level: LayerXLogLevel.fatal,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      );
      final error = _mk(
        id: 'a regular error',
        level: LayerXLogLevel.error,
        timestamp: DateTime(2026, 1, 1, 10, 0, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxProblemsPane(
              logs: [error, fatal],
              onInspect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('app crashed hard'), findsOneWidget);
      expect(find.text('a regular error'), findsOneWidget);
    });
  });
}
