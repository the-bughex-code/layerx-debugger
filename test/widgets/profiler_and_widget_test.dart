import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  group('LayerXProfiler', () {
    test('measure returns the value and logs the duration', () async {
      final result = await LayerXProfiler.measure('job', () async {
        return 42;
      });

      expect(result, 42);
      expect(
        LayerXLogStore.logs.any((e) => e.message.contains('job completed in')),
        isTrue,
      );
    });

    test('measureSync returns the value and logs', () {
      final result = LayerXProfiler.measureSync('calc', () => 7);
      expect(result, 7);
      expect(
        LayerXLogStore.logs.any((e) => e.message.contains('calc completed in')),
        isTrue,
      );
    });

    test('start/end logs a span and returns a duration', () {
      LayerXProfiler.start('span');
      final elapsed = LayerXProfiler.end('span');
      expect(elapsed, isNotNull);
      expect(
        LayerXLogStore.logs.any((e) => e.message.contains('span completed in')),
        isTrue,
      );
    });

    test('end returns null for an unknown tag', () {
      expect(LayerXProfiler.end('never-started'), isNull);
    });

    test('enablePerformanceLogs gates output', () async {
      await LayerXDebugger.initialize(
        config: const LayerXDebugConfig(enablePerformanceLogs: false),
      );
      LayerXLogStore.clear();
      LayerXProfiler.measureSync('quiet', () => 1);
      expect(LayerXLogStore.logs, isEmpty);
    });
  });

  group('LayerXDebugWidget', () {
    testWidgets('logs an increasing rebuild count', (tester) async {
      final notifier = ValueNotifier<int>(0);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (_, value, __) => LayerXDebugWidget(
              tag: 'Counter',
              child: Text('$value'),
            ),
          ),
        ),
      );
      await tester.pump();

      notifier.value = 1;
      await tester.pump();
      await tester.pump();

      final rebuildLogs = LayerXLogStore.logs
          .where((e) => e.message.contains('Counter rebuilt'));
      expect(rebuildLogs, isNotEmpty);
    });
  });
}
