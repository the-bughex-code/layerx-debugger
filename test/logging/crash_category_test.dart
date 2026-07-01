import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  setUp(LayerXLogStore.clear);

  test('FlutterError.onError routes a RenderFlex overflow to uiException', () {
    LayerXCrashHandler.uninstall();
    final original = FlutterError.onError;
    FlutterError.onError = (_) {}; // swallow the chained call
    addTearDown(() {
      LayerXCrashHandler.uninstall();
      FlutterError.onError = original;
    });

    LayerXCrashHandler.install();
    FlutterError.onError!(FlutterErrorDetails(
      exception: FlutterError('A RenderFlex overflowed by 3.0 pixels.'),
      library: 'rendering library',
      context: ErrorDescription('during layout'),
    ));

    final entry = LayerXLogStore.logs
        .firstWhere((l) => l.message.contains('RenderFlex'));
    expect(entry.category, LayerXLogCategory.uiException);
  });
}
