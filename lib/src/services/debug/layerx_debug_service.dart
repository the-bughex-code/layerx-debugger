import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/layerx_architecture_detector.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_architecture_report.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

/// The orchestrating GetX service for the LayerX debugger.
///
/// Provides access to the detected architecture and the captured log store.
class LayerXDebugService extends GetxService {
  /// A snapshot of the current architecture detection.
  LayerXArchitectureReport get report =>
      LayerXArchitectureDetector.detect(LayerXDebugger.config);

  /// All captured log entries, newest first.
  List<LayerXLogEntry> get logs => LayerXLogStore.logs;

  /// Clears all captured logs.
  void clearLogs() => LayerXLogStore.clear();
}
