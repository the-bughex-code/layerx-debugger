import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXConsoleCapture.reset);

  test('a debugPrint after install is captured as a debugConsole entry', () {
    LayerXConsoleCapture.install();
    debugPrint('hello from debugPrint');
    final logs = LayerXLogStore.logs;
    expect(logs, hasLength(1));
    expect(logs.first.category, LayerXLogCategory.debugConsole);
    expect(logs.first.message, 'hello from debugPrint');
  });

  test('guard() suppresses capture of LayerX-owned output', () {
    LayerXConsoleCapture.install();
    LayerXConsoleCapture.guard(() => debugPrint('internal echo'));
    expect(LayerXLogStore.logs, isEmpty);
  });

  test('reset restores the original debugPrint (no capture after reset)', () {
    LayerXConsoleCapture.install();
    LayerXConsoleCapture.reset();
    debugPrint('after reset');
    expect(LayerXLogStore.logs, isEmpty);
  });
}
