import 'package:flutter/widgets.dart';

import '../core/layerx_debugger.dart';
import '../logger/layerx_console_printer.dart';
import '../models/layerx_journey_step.dart';
import '../models/layerx_log_entry.dart';
import '../models/layerx_log_level.dart';
import '../models/layerx_log_source.dart';
import '../utils/layerx_duplicate_guard.dart';
import '../utils/layerx_log_store.dart';

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

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(route, previousRoute, 'PUSH');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute(route, previousRoute, 'POP');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRoute(newRoute, oldRoute, 'REPLACE');
  }
}
