import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/profiler/layerx_profiler.dart';

/// A GetX service exposing LayerX performance profiling.
class LayerXPerformanceService extends GetxService {
  /// Runs and times an asynchronous [action] labelled [name].
  Future<T> measure<T>(String name, Future<T> Function() action) =>
      LayerXProfiler.measure(name, action);

  /// Starts a manual span labelled [tag].
  void start(String tag) => LayerXProfiler.start(tag);

  /// Stops the span [tag], logging and returning its duration.
  Duration? end(String tag) => LayerXProfiler.end(tag);
}
