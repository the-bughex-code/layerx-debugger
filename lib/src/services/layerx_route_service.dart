import 'package:get/get.dart';

import '../core/layerx_debugger.dart';
import '../navigation/layerx_route_observer.dart';

/// A GetX service exposing the shared [LayerXRouteObserver].
class LayerXRouteService extends GetxService {
  /// The route observer to register in `navigatorObservers`.
  LayerXRouteObserver get observer => LayerXDebugger.routeObserver;
}
