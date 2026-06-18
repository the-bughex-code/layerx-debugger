import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/performance/layerx_frame_monitor.dart';

void main() {
  group('LayerXFrameMonitor.shouldLog', () {
    test('ignores frames under the jank threshold', () {
      expect(LayerXFrameMonitor.shouldLog(16.0, 0, 5 * 1000 * 1000), isFalse);
      expect(LayerXFrameMonitor.shouldLog(47.9, 0, 5 * 1000 * 1000), isFalse);
    });

    test('reports a janky frame when the rate-limit window has elapsed', () {
      // last logged at t=0, now at t=2s → window elapsed.
      expect(LayerXFrameMonitor.shouldLog(60.0, 0, 2 * 1000 * 1000), isTrue);
    });

    test('rate-limits repeated janky frames within the window', () {
      const last = 1000 * 1000; // 1s
      final within = last + 500 * 1000; // +0.5s, inside 1s window
      expect(LayerXFrameMonitor.shouldLog(60.0, last, within), isFalse);
    });
  });
}
