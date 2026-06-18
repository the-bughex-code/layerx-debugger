import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/layerx_architecture_detector.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// Adds LayerX lifecycle logging to any GetX controller or service.
///
/// Mix it into a controller you already have:
///
/// ```dart
/// class HomeController extends GetxController with LayerXDebugMixin {}
/// ```
///
/// `onInit`, `onReady` and `onClose` are logged when
/// [LayerXDebugConfig.enableGetXLogs] is set. The mixin is constrained to
/// [DisposableInterface], the common base of `GetxController` and `GetxService`.
mixin LayerXDebugMixin on DisposableInterface {
  void _logLifecycle(String event) {
    final config = LayerXDebugger.config;
    if (!config.enableGetXLogs) return;
    LayerXLog.log(
      level: LayerXLogLevel.info,
      message: '$runtimeType.$event()',
      controller: runtimeType.toString(),
      service: 'GetX',
      method: event,
    );
  }

  @override
  void onInit() {
    super.onInit();
    LayerXArchitectureDetector.markControllers();
    _logLifecycle('onInit');
  }

  @override
  void onReady() {
    super.onReady();
    _logLifecycle('onReady');
  }

  @override
  void onClose() {
    _logLifecycle('onClose');
    super.onClose();
  }
}
