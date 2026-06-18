import 'package:get/get.dart';

import 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';

/// A GetX service that owns global crash capture.
///
/// On registration it ensures the global error hooks are installed (idempotent).
class LayerXCrashService extends GetxService {
  @override
  void onInit() {
    super.onInit();
    LayerXCrashHandler.install();
  }

  /// Runs [body] in a guarded zone, capturing uncaught async errors.
  R? runGuarded<R>(R Function() body) => LayerXCrashHandler.runGuarded<R>(body);
}
