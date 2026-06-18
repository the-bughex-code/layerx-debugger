import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// Captures uncaught errors from every source and records them as log entries.
///
/// Hooks [FlutterError.onError] (framework errors), the
/// [PlatformDispatcher.onError] (uncaught async errors) and, via
/// [runGuarded], a guarded zone. Each captured error is also forwarded to
/// [LayerXDebugConfig.onCrash] so it can be sent to Crashlytics, Sentry, etc.
class LayerXCrashHandler {
  LayerXCrashHandler._();

  static bool _installed = false;
  static FlutterExceptionHandler? _previousFlutterOnError;

  /// Installs the global error hooks. Idempotent — safe to call repeatedly.
  ///
  /// The hooks read the live [LayerXDebugger.config], so toggling
  /// [LayerXDebugConfig.enableCrashLogs] or changing [LayerXDebugConfig.onCrash]
  /// takes effect without re-installing.
  static void install() {
    if (_installed) return;
    _installed = true;

    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final config = LayerXDebugger.config;
      if (config.enableCrashLogs) {
        _record(
          details.exceptionAsString(),
          details.exception,
          details.stack,
          fatal: false,
          library: details.library,
        );
        config.onCrash?.call(
          details.exception,
          details.stack ?? StackTrace.current,
          false,
        );
      }
      final previous = _previousFlutterOnError;
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      final config = LayerXDebugger.config;
      if (config.enableCrashLogs) {
        _record(error.toString(), error, stack, fatal: true);
        config.onCrash?.call(error, stack, true);
      }
      return false;
    };
  }

  /// Runs [body] inside a guarded zone, recording (and forwarding) any uncaught
  /// asynchronous error. Returns the result of [body], or `null` if it threw.
  static R? runGuarded<R>(R Function() body) {
    return runZonedGuarded<R>(body, (error, stack) {
      final config = LayerXDebugger.config;
      if (config.enableCrashLogs) {
        _record(error.toString(), error, stack, fatal: true);
        config.onCrash?.call(error, stack, true);
      }
    });
  }

  static void _record(
    String message,
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? library,
  }) {
    LayerXLogOutput.ingest(
      level: fatal ? LayerXLogLevel.fatal : LayerXLogLevel.error,
      message: fatal ? '💀 FATAL: $message' : message,
      error: error,
      stackTrace: stack,
      extras: {
        if (library != null) 'library': library,
        if (fatal) 'fatal': true,
      },
      packageName: LayerXDebugger.config.packageName,
    );
  }
}
