import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

class _DemoController extends LayerXController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LayerXDebugger.resetForTesting();
    Get.reset();
    LayerXLogStore.clear();
  });

  test('initialize registers the GetX services in a LayerX app', () async {
    await LayerXDebugger.initialize();

    expect(Get.isRegistered<LayerXLoggerService>(), isTrue);
    expect(Get.isRegistered<LayerXDebugService>(), isTrue);
    expect(Get.isRegistered<LayerXCrashService>(), isTrue);
    expect(Get.isRegistered<LayerXNetworkService>(), isTrue);
    expect(Get.isRegistered<LayerXPerformanceService>(), isTrue);
    expect(Get.isRegistered<LayerXRouteService>(), isTrue);
  });

  test('skips injection when not a LayerX architecture', () async {
    await LayerXDebugger.initialize(
      config: const LayerXDebugConfig(isLayerXArchitecture: false),
    );

    expect(Get.isRegistered<LayerXLoggerService>(), isFalse);
    expect(Get.isRegistered<LayerXDebugService>(), isFalse);
  });

  test('skips injection when autoInject is disabled', () async {
    await LayerXDebugger.initialize(
      config: const LayerXDebugConfig(autoInject: false),
    );
    expect(Get.isRegistered<LayerXLoggerService>(), isFalse);
  });

  test('double initialize is safe and keeps services registered', () async {
    await LayerXDebugger.initialize();
    await LayerXDebugger.initialize();
    expect(Get.isRegistered<LayerXDebugService>(), isTrue);
  });

  test('controllers module activates when a LayerXController runs', () async {
    await LayerXDebugger.initialize();
    final debug = Get.find<LayerXDebugService>();
    expect(debug.report.controllersDetected, isFalse);

    Get.put(_DemoController());
    expect(debug.report.controllersDetected, isTrue);
    Get.delete<_DemoController>();
  });

  test('network module activates on the first logged request', () async {
    await LayerXDebugger.initialize();
    final debug = Get.find<LayerXDebugService>();
    expect(debug.report.networkDetected, isFalse);

    LayerXNetworkLogger.record(
      endpoint: '/x',
      method: 'GET',
      statusCode: 200,
      responseBody: '{}',
    );
    expect(debug.report.networkDetected, isTrue);
  });
}
