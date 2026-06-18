import 'package:flutter/scheduler.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';

/// Automatically captures janky frames (frame drops) and records them as
/// performance warnings in the LayerX viewer.
///
/// Hooks [SchedulerBinding.addTimingsCallback]. A frame is considered janky
/// when its total span exceeds [jankThresholdMs] (~3 dropped frames at 60 fps).
/// Logging is rate-limited to one entry per [minIntervalMs] so a sustained
/// stutter does not flood the log.
abstract final class LayerXFrameMonitor {
  /// Frames slower than this (milliseconds) are reported. ~3 frames at 60 fps.
  static const double jankThresholdMs = 48.0;

  /// Minimum gap between two reported slow frames, in milliseconds.
  static const int minIntervalMs = 1000;

  static bool _installed = false;
  static int _lastLoggedMicros = 0;

  /// Installs the timings callback. No-op if already installed or if
  /// performance logging is disabled.
  static void install() {
    if (_installed) return;
    if (!LayerXDebugger.config.enablePerformanceLogs) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final totalMs = t.totalSpan.inMicroseconds / 1000.0;
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      if (!shouldLog(totalMs, _lastLoggedMicros, nowMicros)) continue;
      _lastLoggedMicros = nowMicros;

      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      LayerXLog.log(
        level: LayerXLogLevel.warning,
        message: '🐢 Slow frame: ${totalMs.toStringAsFixed(1)}ms '
            '(build ${buildMs.toStringAsFixed(1)}ms · '
            'raster ${rasterMs.toStringAsFixed(1)}ms)',
        service: 'Performance',
        method: 'frame',
        extras: {'duration_ms': totalMs.round()},
      );
    }
  }

  /// Pure decision: report a slow frame only when it exceeds [jankThresholdMs]
  /// and the rate-limit window has elapsed since the last reported frame.
  static bool shouldLog(double totalMs, int lastLoggedMicros, int nowMicros) {
    if (totalMs < jankThresholdMs) return false;
    return (nowMicros - lastLoggedMicros) >= minIntervalMs * 1000;
  }

  /// Resets installation state. Used by tests.
  static void reset() {
    _installed = false;
    _lastLoggedMicros = 0;
  }
}
