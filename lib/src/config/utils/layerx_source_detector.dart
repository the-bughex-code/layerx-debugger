import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';

/// Classifies the likely [LayerXLogSource] of a log entry from its status code,
/// message and stack trace.
class LayerXSourceDetector {
  LayerXSourceDetector._();

  /// Returns the best-guess source for the given signals.
  ///
  /// Heuristics, in order: `5xx` → [LayerXLogSource.server], `4xx` →
  /// [LayerXLogSource.backend], connectivity keywords → network, common Dart
  /// runtime errors → app, otherwise [LayerXLogSource.unknown].
  static LayerXLogSource detect({
    int? statusCode,
    String? message,
    String? stackTrace,
  }) {
    final msg = (message ?? '').toLowerCase();
    final trace = (stackTrace ?? '').toLowerCase();

    if (statusCode != null) {
      if (statusCode == 500 ||
          statusCode == 502 ||
          statusCode == 503 ||
          statusCode == 504) {
        return LayerXLogSource.server;
      }
      if (statusCode >= 400 && statusCode < 500) {
        return LayerXLogSource.backend;
      }
    }

    if (msg.contains('socketexception') ||
        msg.contains('timeout') ||
        msg.contains('no internet') ||
        msg.contains('connection refused') ||
        msg.contains('dioexception') ||
        msg.contains('network') ||
        msg.contains('httpexception') ||
        trace.contains('socketexception') ||
        trace.contains('dioexception')) {
      return LayerXLogSource.network;
    }

    if (msg.contains('null check operator') ||
        msg.contains('rangeerror') ||
        msg.contains('nosuchmethod') ||
        msg.contains('setstate after dispose') ||
        msg.contains('bad state') ||
        msg.contains('is not subtype of') ||
        trace.contains('null check') ||
        trace.contains('rangeerror') ||
        trace.contains('nosuchmethod') ||
        trace.contains('setstate') ||
        trace.contains('bad state') ||
        trace.contains('subtype of')) {
      return LayerXLogSource.app;
    }

    return LayerXLogSource.unknown;
  }
}
