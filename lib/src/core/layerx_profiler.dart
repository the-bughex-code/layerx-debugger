import 'layerx_debugger.dart';
import '../logger/layerx_log.dart';
import '../models/layerx_log_level.dart';

/// Measures how long operations take and logs the result.
///
/// Three styles are supported:
///
/// ```dart
/// // 1. Manual span
/// LayerXProfiler.start('load');
/// // ... work ...
/// LayerXProfiler.end('load');
///
/// // 2. Async
/// final users = await LayerXProfiler.measure(() => api.fetchUsers(), tag: 'fetchUsers');
///
/// // 3. Sync
/// final total = LayerXProfiler.measureSync(() => compute(), tag: 'compute');
/// ```
///
/// Output is gated by [LayerXDebugConfig.enablePerformanceLogs].
class LayerXProfiler {
  LayerXProfiler._();

  static final Map<String, Stopwatch> _running = {};

  /// Starts timing a span identified by [tag]. Pair with [end].
  static void start(String tag) {
    _running[tag] = Stopwatch()..start();
  }

  /// Stops the span [tag], logs the elapsed time and returns it.
  ///
  /// Returns `null` if [start] was never called for [tag].
  static Duration? end(String tag) {
    final stopwatch = _running.remove(tag);
    if (stopwatch == null) return null;
    stopwatch.stop();
    _report(tag, stopwatch.elapsed);
    return stopwatch.elapsed;
  }

  /// Runs and times an asynchronous [action] labelled [name], logging its
  /// duration, e.g. `Fetch User completed in 300.00ms`.
  static Future<T> measure<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _report(name, stopwatch.elapsed);
    }
  }

  /// Runs and times a synchronous [action] labelled [name], logging its
  /// duration.
  static T measureSync<T>(
    String name,
    T Function() action,
  ) {
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      _report(name, stopwatch.elapsed);
    }
  }

  static void _report(String name, Duration elapsed) {
    if (!LayerXDebugger.config.enablePerformanceLogs) return;
    final ms = elapsed.inMicroseconds / 1000.0;
    LayerXLog.log(
      level: LayerXLogLevel.info,
      message: '⏱ $name completed in ${ms.toStringAsFixed(2)}ms',
      service: 'Profiler',
      method: name,
      extras: {'duration_ms': ms},
    );
  }
}
