import 'package:flutter/widgets.dart';

import '../core/layerx_debugger.dart';
import 'lx_edge_trigger.dart';
import 'lx_fab_trigger.dart';

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

    return Stack(
      children: [
        child,
        if (config.enableEdgeSwipe) const LxEdgeTrigger(),
        if (config.enableFloatingButton) const LxFabTrigger(),
      ],
    );
  }
}
