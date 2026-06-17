import 'package:logger/logger.dart';

import '../core/layerx_debugger.dart';
import '../models/layerx_log_level.dart';

/// A [LogPrinter] that wraps the `logger` package's [PrettyPrinter] and
/// prefixes each line with a compact timestamp and level tag.
class LayerXPrettyPrinter extends LogPrinter {
  final PrettyPrinter _pretty;

  /// Creates the printer. [colors] toggles ANSI coloring.
  LayerXPrettyPrinter({required bool colors})
      : _pretty = PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 100,
          colors: colors,
          printEmojis: true,
          levelColors: {
            Level.trace: const AnsiColor.fg(244),
            Level.debug: const AnsiColor.fg(244),
            Level.info: const AnsiColor.fg(39),
            Level.warning: const AnsiColor.fg(214),
            Level.error: const AnsiColor.fg(196),
            Level.fatal: const AnsiColor.fg(199),
          },
          levelEmojis: {
            Level.trace: '📓 ',
            Level.debug: '🌀 ',
            Level.info: '🩵 ',
            Level.warning: '⚡ ',
            Level.error: '⛔ ',
            Level.fatal: '🔥 ',
          },
        );

  @override
  List<String> log(LogEvent event) {
    final output = _pretty.log(event);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final levelName = event.level.name.toUpperCase();
    return output.map((line) => '[📅 $time].[$levelName] $line').toList();
  }
}

/// Internal console-logging engine built on the `logger` package.
///
/// Rebuilt lazily after [LayerXDebugger.initialize] so it reflects the active
/// environment (level threshold and colors). The public ergonomic API is
/// [LayerXLog]; this is the underlying engine it prints through.
class LayerXConsoleLogger {
  LayerXConsoleLogger._();

  static Logger? _logger;

  /// The lazily-built logger instance.
  static Logger get instance => _logger ??= _build();

  /// Discards the cached logger so the next access rebuilds it with the
  /// current configuration.
  static void reset() => _logger = null;

  static Logger _build() {
    final config = LayerXDebugger.config;
    return Logger(
      filter: ProductionFilter(),
      level: toLoggerLevel(config.environment.minimumLevel),
      printer: LayerXPrettyPrinter(colors: config.resolvedUseColors),
      // Console only — the in-memory store is populated directly by
      // LayerXLog/LayerXLogOutput, not through this pipeline.
      output: ConsoleOutput(),
    );
  }

  /// Maps a [LayerXLogLevel] to the `logger` package [Level]. `success` has no
  /// native equivalent and is treated as [Level.info] here.
  static Level toLoggerLevel(LayerXLogLevel level) {
    switch (level) {
      case LayerXLogLevel.verbose:
        return Level.trace;
      case LayerXLogLevel.debug:
        return Level.debug;
      case LayerXLogLevel.info:
      case LayerXLogLevel.success:
        return Level.info;
      case LayerXLogLevel.warning:
        return Level.warning;
      case LayerXLogLevel.error:
        return Level.error;
      case LayerXLogLevel.fatal:
        return Level.fatal;
    }
  }

  /// Logs at trace/verbose level.
  static void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.t(message, error: error, stackTrace: stackTrace);

  /// Logs at debug level.
  static void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.d(message, error: error, stackTrace: stackTrace);

  /// Logs at info level.
  static void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.i(message, error: error, stackTrace: stackTrace);

  /// Logs at warning level.
  static void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.w(message, error: error, stackTrace: stackTrace);

  /// Logs at error level.
  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.e(message, error: error, stackTrace: stackTrace);

  /// Logs at fatal level.
  static void f(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      instance.f(message, error: error, stackTrace: stackTrace);
}
