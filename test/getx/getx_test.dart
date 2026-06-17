import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

class _TestController extends LayerXController {}

class _MixedController extends GetxController with LayerXDebugMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  test('LayerXController logs onInit and onClose', () {
    Get.put(_TestController());
    expect(
      LayerXLogStore.logs.any((e) => e.message.contains('onInit')),
      isTrue,
    );

    Get.delete<_TestController>();
    expect(
      LayerXLogStore.logs.any((e) => e.message.contains('onClose')),
      isTrue,
    );
  });

  test('LayerXDebugMixin works on an existing controller', () {
    Get.put(_MixedController());
    expect(
      LayerXLogStore.logs.any(
        (e) => e.message.contains('_MixedController.onInit'),
      ),
      isTrue,
    );
    Get.delete<_MixedController>();
  });

  test('enableGetXLogs gates lifecycle logging', () {
    LayerXDebugger.initialize(
      config: const LayerXDebugConfig(enableGetXLogs: false),
    );
    LayerXLogStore.clear();

    Get.put(_TestController());
    expect(LayerXLogStore.logs, isEmpty);
    Get.delete<_TestController>();
  });
}
