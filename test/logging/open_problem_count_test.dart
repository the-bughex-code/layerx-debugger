import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

LayerXLogEntry _e(String id, LayerXLogLevel level,
        {bool changed = false, int? durationMs}) =>
    LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026),
      level: level, source: LayerXLogSource.app, message: id,
      responseChanged: changed, journey: const [],
      extras: durationMs == null ? const {} : {'duration_ms': durationMs},
    );

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  test('openProblemCount counts errors, fatals, warnings and schema changes', () {
    LayerXLogStore.add(_e('a', LayerXLogLevel.info));
    LayerXLogStore.add(_e('b', LayerXLogLevel.error));
    LayerXLogStore.add(_e('c', LayerXLogLevel.fatal));
    LayerXLogStore.add(_e('d', LayerXLogLevel.warning));
    LayerXLogStore.add(_e('e', LayerXLogLevel.success, changed: true));
    LayerXLogStore.add(_e('f', LayerXLogLevel.debug));
    expect(LayerXLogStore.openProblemCount, 4);
  });

  test('isProblemEntry matches the level/changed rule', () {
    expect(LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.error)), isTrue);
    expect(LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.info)), isFalse);
    expect(
        LayerXLogStore.isProblemEntry(_e('x', LayerXLogLevel.info, changed: true)),
        isTrue);
  });

  group('slow requests count as problems (Task E)', () {
    test(
        'a success entry at or above slowRequestThresholdMs is a problem',
        () {
      expect(
        LayerXLogStore.isProblemEntry(
            _e('x', LayerXLogLevel.success, durationMs: 900)),
        isTrue,
      );
    });

    test('openProblemCount includes a slow success entry (900ms)', () {
      LayerXLogStore.add(_e('a', LayerXLogLevel.info));
      LayerXLogStore.add(_e('slow', LayerXLogLevel.success, durationMs: 900));
      expect(LayerXLogStore.openProblemCount, 1);
    });

    test('the threshold boundary is inclusive: 800ms counts, 799ms does not',
        () {
      expect(
        LayerXLogStore.isProblemEntry(
            _e('at-threshold', LayerXLogLevel.success, durationMs: 800)),
        isTrue,
      );
      expect(
        LayerXLogStore.isProblemEntry(
            _e('below-threshold', LayerXLogLevel.success, durationMs: 799)),
        isFalse,
      );
    });

    test('a non-int duration_ms extra never counts as slow', () {
      final entry = _e('x', LayerXLogLevel.success)
          .copyWith(extras: {'duration_ms': '900'});
      expect(LayerXLogStore.isProblemEntry(entry), isFalse);
    });
  });
}
