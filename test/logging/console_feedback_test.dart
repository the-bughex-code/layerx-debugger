import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXConsoleCapture.reset);

  test('LayerXLog.i produces exactly one entry (its own), not a console echo',
      () {
    LayerXConsoleCapture.install();
    LayerXLog.i('user tapped save');
    final logs = LayerXLogStore.logs;
    // No extra debugConsole entry from the echo.
    expect(logs.where((l) => l.category == LayerXLogCategory.debugConsole),
        isEmpty);
    expect(logs.where((l) => l.message == 'user tapped save'), hasLength(1));
  });
}
