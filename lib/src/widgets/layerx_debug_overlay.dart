import 'package:flutter/widgets.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

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
    // The triggers are now rendered by [LayerXOverlayInstaller] as a single
    // entry in the app's root Overlay, so they appear on every app without any
    // `builder:` wiring. This wrapper stays for backward compatibility: it just
    // ensures the overlay is installed (into the root overlay of this context)
    // and returns [child] unchanged. The shared entry guarantees there is never
    // a duplicate FAB, whether or not an app wraps with this widget.
    if (LayerXDebugger.config.viewerEnabled &&
        !LayerXOverlayInstaller.isInstalled) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        LayerXOverlayInstaller.installInto(overlay);
      } else {
        LayerXOverlayInstaller.ensure();
      }
    }
    return child;
  }
}
