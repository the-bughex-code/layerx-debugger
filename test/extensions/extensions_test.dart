import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  test('logE records an error entry from any value', () {
    'something failed'.logE();
    expect(LayerXLogStore.logs.first.level, LayerXLogLevel.error);
    expect(LayerXLogStore.logs.first.message, contains('something failed'));
  });

  test('logS records a success entry', () {
    42.logS();
    expect(LayerXLogStore.logs.first.level, LayerXLogLevel.success);
    expect(LayerXLogStore.logs.first.message, '42');
  });
}
