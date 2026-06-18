import 'package:flutter/widgets.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// Wraps a widget and logs how many times it rebuilds.
///
/// ```dart
/// LayerXDebugWidget(
///   tag: 'HomeView',
///   child: HomeView(),
/// );
/// ```
///
/// Each rebuild logs `"<tag> rebuilt N times"`. The log is emitted after the
/// frame so it never disturbs the build it is counting. Output is gated by
/// [LayerXDebugConfig.enableWidgetLogs].
class LayerXDebugWidget extends StatefulWidget {
  /// The widget whose rebuilds are tracked.
  final Widget child;

  /// A friendly name for the tracked widget. Defaults to the child's type.
  final String? tag;

  /// Creates a rebuild-tracking wrapper around [child].
  const LayerXDebugWidget({super.key, required this.child, this.tag});

  @override
  State<LayerXDebugWidget> createState() => _LayerXDebugWidgetState();
}

class _LayerXDebugWidgetState extends State<LayerXDebugWidget> {
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    if (LayerXDebugger.config.enableWidgetLogs) {
      final count = _buildCount;
      final name = widget.tag ?? widget.child.runtimeType.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LayerXLog.log(
          level: LayerXLogLevel.info,
          message: '$name rebuilt $count time${count == 1 ? '' : 's'}',
          service: 'Widget',
          method: 'build',
        );
      });
    }
    return widget.child;
  }
}
