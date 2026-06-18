import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/route/layerx_route_observer.dart';

/// A GetX service exposing the shared [LayerXRouteObserver].
class LayerXRouteService extends GetxService {
  /// The route observer to register in `navigatorObservers`.
  LayerXRouteObserver get observer => LayerXDebugger.routeObserver;
}
