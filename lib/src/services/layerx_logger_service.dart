import 'package:get/get.dart';

import '../logger/layerx_log.dart';

/// A GetX service exposing LayerX logging via dependency injection.
///
/// Registered automatically by [LayerXDebugger.initialize] in LayerX apps. The
/// static [LayerXLog] API remains the primary, no-setup entry point; this
/// service is for teams that prefer `Get.find<LayerXLoggerService>()`.
class LayerXLoggerService extends GetxService {
  /// Logs at debug level.
  void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXLog.d(message, error: error, stackTrace: stackTrace);

  /// Logs at info level.
  void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXLog.i(message, error: error, stackTrace: stackTrace);

  /// Logs at warning level.
  void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXLog.w(message, error: error, stackTrace: stackTrace);

  /// Logs at error level.
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXLog.e(message, error: error, stackTrace: stackTrace);

  /// Logs a success.
  void s(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      LayerXLog.s(message, error: error, stackTrace: stackTrace);
}
