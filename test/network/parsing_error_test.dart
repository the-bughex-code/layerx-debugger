import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  test('recordParsingError surfaces a model-mapping warning with the body', () {
    LayerXNetworkLogger.recordParsingError(
      endpoint: '/users/1',
      method: 'GET',
      error: TypeError(),
      responseBody: '{"id":"not-an-int"}',
      modelName: 'User',
    );
    final entry = LayerXLogStore.logs.first;
    expect(entry.level, LayerXLogLevel.warning);
    expect(entry.message, contains('Model mapping failed'));
    expect(entry.message, contains('User'));
    expect(entry.endpoint, '/users/1');
    expect(entry.responsePayload, contains('not-an-int'));
  });
}
