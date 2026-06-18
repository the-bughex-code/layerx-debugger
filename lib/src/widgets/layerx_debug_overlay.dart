import 'package:flutter/widgets.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/widgets/lx_edge_trigger.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';

/// Hosts the in-app LayerX log viewer above your application.
///
/// It overlays a draggable floating debug button and an edge-swipe gesture that
/// open the searchable log list. Wrap your app's content with it, typically via
/// `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => LayerXDebugOverlay(child: child!),
/// );
/// ```
///
/// The overlay shows nothing when [LayerXDebugConfig.viewerEnabled] is false
/// (for example in [LayerXEnvironment.prod]).
class LayerXDebugOverlay extends StatelessWidget {
  /// The application content rendered beneath the viewer triggers.
  final Widget child;

  /// Creates the overlay host around [child].
  const LayerXDebugOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = LayerXDebugger.config;
    if (!config.viewerEnabled) return child;

    // While the debugger shell is open, hide the triggers entirely. This
    // prevents duplicate FABs, overlay conflicts, and visibility bugs, and
    // restores them automatically when the viewer is dismissed.
    return ValueListenableBuilder<bool>(
      valueListenable: LayerXViewerState.isOpen,
      builder: (context, viewerOpen, _) {
        return Stack(
          children: [
            child,
            if (!viewerOpen && config.enableEdgeSwipe) const LxEdgeTrigger(),
            if (!viewerOpen && config.enableFloatingButton) const LxFabTrigger(),
          ],
        );
      },
    );
  }
}
