import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/mvvm/view/lx_log_list_screen.dart';
import 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_logger.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/route/layerx_route_observer.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/core/bindings/layerx_bindings.dart';
import 'package:layerx_debugger/src/core/layerx_architecture_detector.dart';
import 'package:layerx_debugger/src/config/layerx_debug_config.dart';

/// The entry point for LayerX — initialize it once and everything starts
/// working automatically.
///
/// ```dart
/// void main() {
///   LayerXDebugger.runZonedGuarded(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await LayerXDebugger.initialize(
///       config: const LayerXDebugConfig(appName: 'My App'),
///     );
///     runApp(const MyApp());
///   });
/// }
/// ```
///
/// In a LayerX (GetX) app this installs crash handling and auto-registers the
/// LayerX GetX services. In a non-LayerX app (set
/// [LayerXDebugConfig.isLayerXArchitecture] to `false`) it injects nothing and
/// only prints guidance — it never changes app behavior or crashes.
class LayerXDebugger {
  LayerXDebugger._();

  static LayerXDebugConfig _config = const LayerXDebugConfig();
  static LayerXRouteObserver? _routeObserver;
  static bool _initialized = false;

  /// The currently active configuration. Defaults to a development config until
  /// [initialize] is called.
  static LayerXDebugConfig get config => _config;

  /// A shared [LayerXRouteObserver] ready to add to `navigatorObservers`.
  static LayerXRouteObserver get routeObserver =>
      _routeObserver ??= LayerXRouteObserver();

  /// Applies [config], (re)initializes logging, and — on the first call —
  /// installs crash handling and auto-injects the LayerX GetX services when a
  /// LayerX architecture is detected.
  ///
  /// Calling [config] again updates the configuration but the one-time setup
  /// runs only once. The whole routine is wrapped in a guard so the debugger
  /// can never crash the host app.
  static Future<void> initialize({LayerXDebugConfig? config}) async {
    _config = config ?? const LayerXDebugConfig();
    LayerXLogStore.maxStoredLogs = _config.maxStoredLogs;
    LayerXConsoleLogger.reset();

    if (_initialized) {
      LayerXLog.w('[LayerX Debugger] Already initialized. Skipping setup.');
      return;
    }
    _initialized = true;

    try {
      if (_config.enableCrashLogs) {
        LayerXCrashHandler.install();
      }

      final report = LayerXArchitectureDetector.detect(_config);

      if (report.isLayerX && _config.autoInject) {
        LayerXBindings().dependencies();
        LayerXArchitectureDetector.markServices();
      }

      // Re-detect after injection so the banner reflects registered services.
      LayerXArchitectureDetector.printBanner(
        LayerXArchitectureDetector.detect(_config),
      );
    } catch (error, stack) {
      // The debugger must never take the app down.
      LayerXLog.log(
        level: LayerXLogLevel.error,
        message: '[LayerX Debugger] initialization error',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Runs [body] inside a guarded zone so uncaught asynchronous errors are
  /// captured. Use it to wrap `runApp`.
  static R? runZonedGuarded<R>(R Function() body) =>
      LayerXCrashHandler.runGuarded<R>(body);

  /// Opens the in-app log viewer on top of the current screen.
  ///
  /// Call it from any button to show the captured logs on demand:
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => LayerXDebugger.openViewer(context),
  ///   child: const Text('Open logs'),
  /// );
  /// ```
  static Future<void> openViewer(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const LxLogListScreen()),
    );
  }

  /// Resets all initialization state. Intended for tests only.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _config = const LayerXDebugConfig();
    _routeObserver = null;
    LayerXArchitectureDetector.reset();
  }
}
