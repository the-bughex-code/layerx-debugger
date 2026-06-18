import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// A GetX [GetMiddleware] that logs navigation to the pages it is attached to.
///
/// Attach it per page:
///
/// ```dart
/// GetPage(
///   name: '/home',
///   page: () => const HomeView(),
///   middlewares: [LayerXRouteMiddleware()],
/// );
/// ```
///
/// For app-wide route logging prefer [LayerXRouteObserver] in
/// `navigatorObservers`.
class LayerXRouteMiddleware extends GetMiddleware {
  /// Creates the middleware with an optional GetX [priority].
  LayerXRouteMiddleware({super.priority});

  @override
  RouteSettings? redirect(String? route) {
    final config = LayerXDebugger.config;
    if (config.enableRouteLogs &&
        route != null &&
        !route.contains('LayerXLog')) {
      LayerXLog.log(
        level: LayerXLogLevel.info,
        message: 'GetX route → $route',
        screen: route,
        service: 'GetX Router',
        method: 'redirect',
      );
    }
    return null;
  }
}
