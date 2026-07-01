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
  }

  /// Ingests a single captured console [message] unless suppressed by [guard].
  static void capture(String? message) {
    if (_emitting || message == null || message.isEmpty) return;
    guard(() => LayerXLogOutput.ingest(
          level: LayerXLogLevel.debug,
          message: message,
          category: LayerXLogCategory.debugConsole,
        ));
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
