import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';

/// Captures framework/app console output (`debugPrint`, and — via the guarded
/// zone — `print`) into the LayerX log store under
/// [LayerXLogCategory.debugConsole].
///
/// A reentrancy [guard] prevents LayerX's own console echo (and any output
/// produced while ingesting) from being re-captured, which would otherwise
/// create an unbounded feedback loop.
class LayerXConsoleCapture {
  LayerXConsoleCapture._();

  static bool _installed = false;
  static bool _emitting = false;
  static DebugPrintCallback? _previousDebugPrint;

  /// Hard safety cap: the most console lines LayerX will ingest within a single
  /// synchronous burst (one run of app/framework code between event-loop turns).
  /// A burst larger than this — e.g. a logger pretty-printing a big API payload
  /// while a screen builds during navigation — is exactly what could pile enough
  /// synchronous work onto the UI thread to ANR. Past the cap the extra lines
  /// are counted and collapsed into ONE summary entry, so console capture can
  /// never block navigation however chatty the app is. The budget resets on the
  /// next microtask, i.e. as soon as the synchronous burst finishes.
  static const int maxLinesPerBurst = 500;
  static int _burstCount = 0;
  static int _suppressedInBurst = 0;
  static bool _drainScheduled = false;

  /// Whether LayerX is currently emitting its own output (capture is skipped).
  static bool get isEmitting => _emitting;

  /// Installs the `debugPrint` override. Idempotent.
  static void install() {
    if (_installed) return;
    _installed = true;
    _previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _previousDebugPrint!(message, wrapWidth: wrapWidth);
      capture(message);
    };
  }

  /// Restores the original `debugPrint`. Safe to call when not installed.
  static void reset() {
    if (!_installed) return;
    if (_previousDebugPrint != null) debugPrint = _previousDebugPrint!;
    _previousDebugPrint = null;
    _installed = false;
    _emitting = false;
    _burstCount = 0;
    _suppressedInBurst = 0;
    _drainScheduled = false;
  }

  /// Ingests a single captured console [message] unless suppressed by [guard]
  /// or by the per-burst safety cap ([maxLinesPerBurst]).
  static void capture(String? message) {
    if (_emitting || message == null || message.isEmpty) return;

    // Bound the synchronous work console capture can add to any one burst so a
    // flood (a logger dumping a huge payload during navigation) can never block
    // the UI thread. Past the cap, count and summarise instead of ingesting.
    if (_burstCount >= maxLinesPerBurst) {
      _suppressedInBurst++;
      return;
    }
    _burstCount++;
    _scheduleBurstReset();

    guard(() => LayerXLogOutput.ingest(
          level: LayerXLogLevel.debug,
          message: message,
          category: LayerXLogCategory.debugConsole,
          // Raw console echoes carry no useful source location (the stack would
          // just be the debugPrint→capture plumbing), and this is the highest-
          // volume ingest path. Skipping the StackTrace.current capture here is
          // what keeps a flood of console lines from blocking the UI thread.
          resolveLocation: false,
        ));
  }

  /// Resets the per-burst budget on the next microtask (once the current
  /// synchronous burst finishes) and, if any lines were dropped, records a
  /// single summary entry. Uses a microtask (not a frame callback) so the bound
  /// tracks synchronous runs exactly and needs no widget binding.
  static void _scheduleBurstReset() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      final dropped = _suppressedInBurst;
      _burstCount = 0;
      _suppressedInBurst = 0;
      _drainScheduled = false;
      if (dropped > 0) {
        guard(() => LayerXLogOutput.ingest(
              level: LayerXLogLevel.debug,
              category: LayerXLogCategory.debugConsole,
              resolveLocation: false,
              message: '… $dropped more console line(s) suppressed by LayerX in '
                  'one burst to keep the UI responsive',
            ));
      }
    });
  }

  /// Runs [body] with capture suppressed. Wrap every LayerX-owned console write
  /// so it is not re-captured.
  static T guard<T>(T Function() body) {
    final previous = _emitting;
    _emitting = true;
    try {
      return body();
    } finally {
      _emitting = previous;
    }
  }
}
