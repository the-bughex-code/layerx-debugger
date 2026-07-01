import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/services/crash/layerx_error_classifier.dart';
import 'package:layerx_debugger/src/services/crash/layerx_isolate_hook.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';

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
  static void Function()? _isolateClose;

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
          category: LayerXErrorClassifier.classifyFlutterError(
            library: details.library,
            description: details.exceptionAsString(),
          ),
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
        _record(error.toString(), error, stack,
            fatal: true,
            category: LayerXErrorClassifier.classifyUncaught(fatal: true));
        config.onCrash?.call(error, stack, true);
      }
      return false;
    };

    _isolateClose = installIsolateErrorHook((error, stack) {
      final config = LayerXDebugger.config;
      if (config.enableCrashLogs) {
        _record(error.toString(), error, stack,
            fatal: true,
            category: LayerXErrorClassifier.classifyUncaught(fatal: true));
        config.onCrash?.call(error, stack, true);
      }
    });
  }

  /// Runs [body] inside a guarded zone, recording (and forwarding) any uncaught
  /// asynchronous error. Returns the result of [body], or `null` if it threw.
  static R? runGuarded<R>(R Function() body) {
    return runZonedGuarded<R>(
      body,
      (error, stack) {
        final config = LayerXDebugger.config;
        if (config.enableCrashLogs) {
          _record(error.toString(), error, stack,
              fatal: true,
              category: LayerXErrorClassifier.classifyUncaught(fatal: true));
          config.onCrash?.call(error, stack, true);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line);
          if (!kReleaseMode) LayerXConsoleCapture.capture(line);
        },
      ),
    );
  }

  /// Removes the isolate error listener and clears the install guard.
  /// Intended for tests and hot-restart; does not restore FlutterError.onError.
  static void uninstall() {
    _isolateClose?.call();
    _isolateClose = null;
    _installed = false;
  }

  static void _record(
    String message,
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? library,
    LayerXLogCategory category = LayerXLogCategory.app,
  }) {
    LayerXLogOutput.ingest(
      level: fatal ? LayerXLogLevel.fatal : LayerXLogLevel.error,
      message: fatal ? '💀 FATAL: $message' : message,
      category: category,
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
