import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  test('flags a JSON 2xx whose body is not valid JSON as a warning', () {
    LayerXNetworkLogger.record(
      endpoint: '/profile',
      method: 'GET',
      statusCode: 200,
      responseBody: '<html>Service Unavailable</html>',
      responseHeaders: {'content-type': 'application/json; charset=utf-8'},
      durationMs: 30,
    );
    final entry = LayerXLogStore.logs.first;
    expect(entry.level, LayerXLogLevel.warning);
    expect(entry.message, contains('Unexpected response structure'));
    expect(entry.suggestedSolution, isNotNull);
  });

  test('does not flag a non-JSON content-type that fails to parse', () {
    LayerXNetworkLogger.record(
      endpoint: '/page',
      method: 'GET',
      statusCode: 200,
      responseBody: '<html>ok</html>',
      responseHeaders: {'content-type': 'text/html'},
      durationMs: 10,
    );
    final entry = LayerXLogStore.logs.first;
    expect(entry.level, LayerXLogLevel.success);
  });
}
