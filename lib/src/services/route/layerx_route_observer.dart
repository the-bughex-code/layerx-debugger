import 'package:flutter/widgets.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/config/utils/layerx_console_printer.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_journey_step.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/config/utils/layerx_duplicate_guard.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

/// A [NavigatorObserver] that records route pushes, pops and replacements.
///
/// Add it to your app:
///
/// ```dart
/// MaterialApp(navigatorObservers: [LayerXRouteObserver()]);
/// // or with GetX:
/// GetMaterialApp(navigatorObservers: [LayerXRouteObserver()]);
/// ```
class LayerXRouteObserver extends NavigatorObserver {
  void _logRoute(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
    String action,
  ) {
    final config = LayerXDebugger.config;
    if (!config.enableRouteLogs) return;

    final name = route?.settings.name;
    if (name == null) return;
    // Never log the viewer's own screens.
    if (name.contains('LayerXLog') || name.contains('LxLog')) return;

    final prevName = previousRoute?.settings.name;
    final now = DateTime.now();
    final message =
        '$action to route: $name${prevName != null ? ' (from $prevName)' : ''}';

    final dedupKey = LayerXDuplicateGuard.generateKey(
      levelName: LayerXLogLevel.info.name,
      message: message,
      screenName: name,
      methodName: action,
    );
    if (LayerXDuplicateGuard.findDuplicate(dedupKey, now) != null) return;

    LayerXConsolePrinter.printLine(
      LayerXLogLevel.info,
      'ROUTE $message',
      colors: config.resolvedUseColors,
    );

    LayerXLogStore.add(LayerXLogEntry(
      id: now.microsecondsSinceEpoch.toString(),
      dedupKey: dedupKey,
      timestamp: now,
      level: LayerXLogLevel.info,
      source: LayerXLogSource.app,
      category: LayerXLogCategory.navigation,
      message: message,
      screenName: name,
      methodName: action,
      serviceName: 'Navigation',
      journey: [
        LayerXJourneyStep(
          timestamp: now,
          title: 'Route Changed',
          description: message,
          type: 'ui',
        ),
      ],
      extras: {
        'route_name': name,
        'previous_route_name': prevName,
        'action': action,
      },
    ));
  }

  /// Ensures the debug triggers are mounted in this navigator's overlay and
  /// kept above the current route. This is what makes the FAB appear on apps
  /// that never wired `LayerXDebugOverlay` into `MaterialApp.builder`.
  void _ensureTriggers() {
    // Never let overlay wiring interfere with route logging or the host app.
    try {
      final overlay = navigator?.overlay;
      if (overlay != null && overlay.mounted) {
        LayerXOverlayInstaller.installInto(overlay);
      } else {
        // The overlay may not exist yet at the first didPush; fall back to the
        // post-frame element-tree lookup, which resolves once the app is built.
        LayerXOverlayInstaller.ensure();
      }
    } catch (_) {}
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(route, previousRoute, 'PUSH');
    _ensureTriggers();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute(route, previousRoute, 'POP');
    _ensureTriggers();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRoute(newRoute, oldRoute, 'REPLACE');
    _ensureTriggers();
  }
}
