import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

/// Classifies captured errors into a [LayerXLogCategory].
class LayerXErrorClassifier {
  LayerXErrorClassifier._();

  /// Categorizes a `FlutterError.onError` report from its [library] tag and
  /// [description]. Rendering/widget/layout problems (including overflow) are
  /// [LayerXLogCategory.uiException]; everything else is
  /// [LayerXLogCategory.framework].
  static LayerXLogCategory classifyFlutterError({
    String? library,
    String? description,
  }) {
    final lib = (library ?? '').toLowerCase();
    final desc = (description ?? '').toLowerCase();
    final isUi = lib.contains('rendering') ||
        lib.contains('widgets') ||
        lib.contains('painting') ||
        desc.contains('overflow') ||
        desc.contains('renderflex') ||
        desc.contains('constraints') ||
        desc.contains('setstate');
    return isUi ? LayerXLogCategory.uiException : LayerXLogCategory.framework;
  }

  /// Categorizes an uncaught async/platform/zone/isolate error.
  static LayerXLogCategory classifyUncaught({required bool fatal}) =>
      fatal ? LayerXLogCategory.crash : LayerXLogCategory.dartException;
}
