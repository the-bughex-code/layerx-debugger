import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';
import 'package:layerx_debugger/src/services/performance/layerx_frame_monitor.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_logger.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/route/layerx_route_observer.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/core/bindings/layerx_bindings.dart';
import 'package:layerx_debugger/src/core/layerx_architecture_detector.dart';
import 'package:layerx_debugger/src/config/layerx_debug_config.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

/// Whether we're running under the Flutter test binding. Used to skip the
/// global `debugPrint` override, which would otherwise trip
/// `debugAssertAllFoundationVarsUnset` between widget tests. Production apps
/// use `WidgetsFlutterBinding` (no 'Test' in the runtime type).
bool _runningUnderFlutterTest() {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return false;
  }
}

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

      if (!kReleaseMode &&
          _config.enableCrashLogs &&
          !_runningUnderFlutterTest()) {
        LayerXConsoleCapture.install();
      }

      if (_config.enablePerformanceLogs) {
        LayerXFrameMonitor.install();
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

      // Auto-mount the in-app debug triggers (FAB + edge swipe) into the root
      // overlay, so the viewer works with zero `MaterialApp.builder` wiring.
      if (_config.viewerEnabled) {
        LayerXOverlayInstaller.ensure();
      }
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
  static Future<void> openViewer(BuildContext context) async {
    final nav = findNavigator(context);
    if (nav != null) {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const LxDebuggerShell()),
      );
    } else {
      try {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const LxDebuggerShell()),
        );
      } catch (e, stack) {
        LayerXLog.log(
          level: LayerXLogLevel.error,
          message: '[LayerX Debugger] Failed to open viewer: Navigator not found.',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  /// Robustly searches for a [NavigatorState] in the widget tree.
  static NavigatorState? findNavigator(BuildContext context) {
    // 1. Try using the routeObserver navigator first
    final observerNav = _routeObserver?.navigator;
    if (observerNav != null) return observerNav;

    // 2. Try standard context search
    try {
      final nav = Navigator.maybeOf(context, rootNavigator: true);
      if (nav != null) return nav;
    } catch (_) {}

    // 3. Downward traversal from the root element
    NavigatorState? found;
    void visitor(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visitor);
    }

    if (context is Element) {
      Element? root = context;
      context.visitAncestorElements((ancestor) {
        root = ancestor;
        return true;
      });
      root?.visitChildren(visitor);
    }

    return found;
  }

  /// Resets all initialization state. Intended for tests only.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _config = const LayerXDebugConfig();
    _routeObserver = null;
    LayerXArchitectureDetector.reset();
    LayerXFrameMonitor.reset();
    LayerXConsoleCapture.reset();
    LayerXOverlayInstaller.reset();
  }
}
