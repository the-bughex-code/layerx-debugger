import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('derives api when an endpoint is present', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'call',
      endpoint: '/users',
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.api);
  });

  test('derives app when there is no endpoint', () {
    LayerXLogOutput.ingest(level: LayerXLogLevel.info, message: 'hi');
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.app);
  });

  test('an explicit category wins over derivation', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.debug,
      message: 'printed',
      category: LayerXLogCategory.debugConsole,
    );
    expect(LayerXLogStore.logs.first.category, LayerXLogCategory.debugConsole);
  });
}
