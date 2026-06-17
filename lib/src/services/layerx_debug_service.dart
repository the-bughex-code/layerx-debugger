import 'package:get/get.dart';

import '../core/layerx_architecture_detector.dart';
import '../core/layerx_debugger.dart';
import '../models/layerx_architecture_report.dart';
import '../models/layerx_log_entry.dart';
import '../utils/layerx_log_store.dart';

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
