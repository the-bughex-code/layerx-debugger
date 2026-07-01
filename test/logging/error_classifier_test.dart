import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_error_classifier.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  test('a RenderFlex overflow is a UI exception', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'rendering library',
      description: 'A RenderFlex overflowed by 42 pixels on the right.',
    );
    expect(c, LayerXLogCategory.uiException);
  });

  test('a widgets-library error is a UI exception', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'widgets library',
      description: 'setState() called after dispose()',
    );
    expect(c, LayerXLogCategory.uiException);
  });

  test('a generic framework error falls back to framework', () {
    final c = LayerXErrorClassifier.classifyFlutterError(
      library: 'services library',
      description: 'MissingPluginException',
    );
    expect(c, LayerXLogCategory.framework);
  });

  test('a fatal uncaught error is a crash; non-fatal is a dart exception', () {
    expect(LayerXErrorClassifier.classifyUncaught(fatal: true),
        LayerXLogCategory.crash);
    expect(LayerXErrorClassifier.classifyUncaught(fatal: false),
        LayerXLogCategory.dartException);
  });
}
