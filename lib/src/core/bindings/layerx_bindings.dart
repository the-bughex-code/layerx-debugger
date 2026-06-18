import 'package:get/get.dart';

import 'package:layerx_debugger/src/services/crash/layerx_crash_service.dart';
import 'package:layerx_debugger/src/services/debug/layerx_debug_service.dart';
import 'package:layerx_debugger/src/services/logger/layerx_logger_service.dart';
import 'package:layerx_debugger/src/services/network/layerx_network_service.dart';
import 'package:layerx_debugger/src/services/performance/layerx_performance_service.dart';
import 'package:layerx_debugger/src/services/route/layerx_route_service.dart';

/// Registers the LayerX GetX services as permanent singletons.
///
/// Used by [LayerXDebugger.initialize], but can also be added to a
/// `GetMaterialApp(initialBinding: LayerXBindings())`. Registration is
/// idempotent — already-registered services are left untouched.
class LayerXBindings extends Bindings {
  @override
  void dependencies() {
    _register<LayerXLoggerService>(LayerXLoggerService());
    _register<LayerXDebugService>(LayerXDebugService());
    _register<LayerXNetworkService>(LayerXNetworkService());
    _register<LayerXPerformanceService>(LayerXPerformanceService());
    _register<LayerXRouteService>(LayerXRouteService());
    // Crash service last so its onInit hooks are installed after the rest.
    _register<LayerXCrashService>(LayerXCrashService());
  }

  void _register<T>(T service) {
    if (!Get.isRegistered<T>()) {
      Get.put<T>(service, permanent: true);
    }
  }
}
