import '../core/layerx_debugger.dart';
import '../models/layerx_log_level.dart';
import 'layerx_console_logger.dart';
import 'layerx_console_printer.dart';
import 'layerx_log_output.dart';

/// The primary logging entry point for LayerX.
///
/// Use the short methods for everyday logging:
///
/// ```dart
/// LayerXLog.d('User fetched');
/// LayerXLog.s('Saved successfully');
/// LayerXLog.e('API failed', error: e, stackTrace: st);
/// ```
///
/// Every call prints a colored console line and records a structured entry in
/// the in-app viewer. Use [log] for fully-structured entries and [apiError]
/// for network failures.
class LayerXLog {
  LayerXLog._();

  /// Logs at debug level (grey).
  static void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.debug, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs at info level (blue).
  static void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.info, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs at warning level (amber).
  static void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.warning, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs at error level (red).
  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.error, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs a success (green) — for example a completed operation.
  static void s(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.success, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs at verbose/trace level (grey).
  static void v(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.verbose, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs at fatal level (bright red).
  static void wtf(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LayerXLogLevel.fatal, _stringify(message),
          error: error, stackTrace: stackTrace);

  /// Logs that a [name]d screen was opened, e.g. `[SCREEN] HomeView opened`.
  static void screen(String name) => _emit(
        LayerXLogLevel.info,
        '[SCREEN] $name opened',
        screen: name,
        service: 'Navigation',
        method: 'screen',
      );

  /// Logs a user [action], e.g. `[ACTION] Login Button Clicked`.
  ///
  /// Optional [data] is attached to the entry's extras for the in-app viewer.
  static void action(String action, {Map<String, dynamic>? data}) => _emit(
        LayerXLogLevel.info,
        '[ACTION] $action',
        service: 'Action',
        method: 'action',
        extras: data,
      );

  /// Logs a fully-structured entry, populating the rich fields shown in the
  /// in-app viewer (screen, controller, service, endpoint, payloads, …).
  static void log({
    required LayerXLogLevel level,
    required String message,
    String? screen,
    String? controller,
    String? service,
    String? repo,
    String? method,
    String? endpoint,
    int? statusCode,
    String? request,
    String? response,
    String? errorCode,
    Map<String, dynamic>? extras,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(
      level,
      message,
      screen: screen,
      method: method,
      controller: controller,
      service: service,
      repo: repo,
      endpoint: endpoint,
      statusCode: statusCode,
      request: request,
      response: response,
      errorCode: errorCode,
      extras: extras,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Shorthand for logging a network/API failure. Maps `5xx` to fatal and
  /// other failures to error.
  static void apiError({
    required String endpoint,
    required int statusCode,
    String? response,
    String? request,
    String? screen,
    String? controller,
    String? method,
    String? errorCode,
    Map<String, dynamic>? extras,
  }) {
    log(
      level: statusCode >= 500 ? LayerXLogLevel.fatal : LayerXLogLevel.error,
      message: 'API Error: $statusCode on $endpoint',
      endpoint: endpoint,
      statusCode: statusCode,
      response: response,
      request: request,
      screen: screen,
      controller: controller,
      method: method,
      errorCode: errorCode,
      extras: extras,
    );
  }

  static void _emit(
    LayerXLogLevel level,
    String message, {
    String? screen,
    String? method,
    String? controller,
    String? service,
    String? repo,
    String? endpoint,
    int? statusCode,
    String? request,
    String? response,
    String? errorCode,
    Map<String, dynamic>? extras,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final config = LayerXDebugger.config;
    if (level.index < config.environment.minimumLevel.index) return;

    _console(level, message, error, stackTrace, config.resolvedUseColors);

    LayerXLogOutput.ingest(
      level: level,
      message: message,
      screen: screen,
      method: method,
      controller: controller,
      service: service,
      repo: repo,
      endpoint: endpoint,
      statusCode: statusCode,
      requestPayload: request,
      responsePayload: response,
      errorCode: errorCode,
      extras: extras,
      error: error,
      stackTrace: stackTrace,
      packageName: config.packageName,
    );
  }

  static void _console(
    LayerXLogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
    bool colors,
  ) {
    switch (level) {
      case LayerXLogLevel.success:
        return LayerXConsolePrinter.printLine(level, message, colors: colors);
      case LayerXLogLevel.verbose:
        return LayerXConsoleLogger.t(message,
            error: error, stackTrace: stackTrace);
      case LayerXLogLevel.debug:
        return LayerXConsoleLogger.d(message,
            error: error, stackTrace: stackTrace);
      case LayerXLogLevel.info:
        return LayerXConsoleLogger.i(message,
            error: error, stackTrace: stackTrace);
      case LayerXLogLevel.warning:
        return LayerXConsoleLogger.w(message,
            error: error, stackTrace: stackTrace);
      case LayerXLogLevel.error:
        return LayerXConsoleLogger.e(message,
            error: error, stackTrace: stackTrace);
      case LayerXLogLevel.fatal:
        return LayerXConsoleLogger.f(message,
            error: error, stackTrace: stackTrace);
    }
  }

  static String _stringify(dynamic message) => message?.toString() ?? 'null';
}
