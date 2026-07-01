import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('a recorded HTTP exchange is categorized as api', () {
    LayerXNetworkLogger.record(
      endpoint: 'https://x/y',
      method: 'GET',
      statusCode: 200,
      responseBody: '{"ok":true}',
      durationMs: 12,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.api);
  });

  test('a transport exception is categorized as network', () {
    LayerXNetworkLogger.recordException(
      endpoint: 'https://x/y',
      method: 'GET',
      error: 'SocketException: failed',
      durationMs: 5,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.network);
  });
}
