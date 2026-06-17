import 'package:layerx_debugger/src/services/logger/layerx_log.dart';

/// Convenience logging methods on any value.
///
/// Import the package and log any object inline:
///
/// ```dart
/// 'User saved'.logS();
/// response.statusCode.logD();
/// caughtError.logE();
/// ```
extension LayerXLogX on Object? {
  /// Logs this value at debug level.
  void logD({Object? error, StackTrace? stackTrace}) =>
      LayerXLog.d(this, error: error, stackTrace: stackTrace);

  /// Logs this value at info level.
  void logI({Object? error, StackTrace? stackTrace}) =>
      LayerXLog.i(this, error: error, stackTrace: stackTrace);

  /// Logs this value at warning level.
  void logW({Object? error, StackTrace? stackTrace}) =>
      LayerXLog.w(this, error: error, stackTrace: stackTrace);

  /// Logs this value at error level.
  void logE({Object? error, StackTrace? stackTrace}) =>
      LayerXLog.e(this, error: error, stackTrace: stackTrace);

  /// Logs this value at success level.
  void logS({Object? error, StackTrace? stackTrace}) =>
      LayerXLog.s(this, error: error, stackTrace: stackTrace);
}
