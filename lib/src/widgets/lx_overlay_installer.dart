// Internal — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/widgets.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/widgets/lx_edge_trigger.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';

/// Inserts the LayerX debug triggers (draggable FAB + edge swipe) into the
/// app's root [Overlay] at runtime, so the in-app viewer works on any app
/// without wiring `LayerXDebugOverlay` into `MaterialApp.builder`.
///
/// A single [OverlayEntry] is shared across all install paths (route observer,
/// `LayerXDebugOverlay`, and [LayerXDebugger.initialize]), so there is never a
/// duplicate FAB. All overlay mutations are deferred to a post-frame callback so
/// they are safe to call from `NavigatorObserver` callbacks (which can fire
/// mid-frame) and from `build`.
abstract final class LayerXOverlayInstaller {
  LayerXOverlayInstaller._();

  static OverlayEntry? _entry;
  static OverlayState? _overlay;
  static bool _scheduled = false;

  /// Whether the trigger overlay is currently inserted.
  static bool get isInstalled => _entry != null;

  /// Inserts the trigger overlay into [overlay] (idempotent). If it is already
  /// inserted in the same overlay, it is brought to the front so it stays above
  /// newly pushed routes.
  static void installInto(OverlayState overlay) {
    if (!LayerXDebugger.config.viewerEnabled) return;
    if (_entry != null && _overlay == overlay) {
      bringToFront();
      return;
    }
    _deferred(() {
      if (_entry != null && _overlay == overlay) return;
      _removeEntry();
      if (!overlay.mounted) return;
      _overlay = overlay;
      _entry = OverlayEntry(builder: (_) => const LxTriggerLayer());
      overlay.insert(_entry!);
    });
  }

  /// Best-effort install: on the next frame, locate the root overlay from the
  /// element tree and install into it. A single attempt (no timers) — the route
  /// observer and [LayerXDebugOverlay] are the primary, reliable paths; this
  /// only covers apps that use neither but call [LayerXDebugger.initialize]
  /// after their first frame.
  static void ensure() {
    if (!LayerXDebugger.config.viewerEnabled) return;
    _deferred(() {
      if (_entry != null) return;
      final overlay = _findRootOverlay();
      if (overlay != null) installInto(overlay);
    });
  }

  /// Re-inserts the entry so it stays on top of routes pushed after it.
  static void bringToFront() {
    _deferred(() {
      final e = _entry;
      final o = _overlay;
      if (e == null || o == null || !o.mounted) return;
      try {
        e.remove();
      } catch (_) {}
      o.insert(e);
    });
  }

  /// Removes the trigger overlay. Intended for tests / hot-restart.
  static void reset() => _removeEntry();

  static void _removeEntry() {
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
    _overlay = null;
    _scheduled = false;
  }

  /// Runs [action] after the current frame, guarded so the debugger can never
  /// crash the host app. Coalesces bursts of calls into a single callback.
  static void _deferred(VoidCallback action) {
    try {
      final binding = WidgetsBinding.instance;
      if (_scheduled) {
        // A callback is already pending; run this one after it next frame.
        binding.addPostFrameCallback((_) => _guard(action));
        return;
      }
      _scheduled = true;
      binding.addPostFrameCallback((_) {
        _scheduled = false;
        _guard(action);
      });
      binding.ensureVisualUpdate();
    } catch (_) {
      // Binding not ready (e.g. a non-widget test) — skip silently.
      _scheduled = false;
    }
  }

  static void _guard(VoidCallback action) {
    try {
      action();
    } catch (_) {
      // Swallow — the debugger must never take the app down.
    }
  }

  static OverlayState? _findRootOverlay() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    OverlayState? found;
    void visit(Element el) {
      if (found != null) return;
      if (el is StatefulElement && el.state is NavigatorState) {
        final o = (el.state as NavigatorState).overlay;
        if (o != null) {
          found = o;
          return;
        }
      }
      el.visitChildren(visit);
    }
    root.visitChildren(visit);
    return found;
  }
}

/// The overlay layer that paints the triggers, hidden while the debugger shell
/// is open (so the FAB never overlaps the viewer).
class LxTriggerLayer extends StatelessWidget {
  const LxTriggerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final config = LayerXDebugger.config;
    if (!config.viewerEnabled) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: LayerXViewerState.isOpen,
      builder: (context, open, _) {
        if (open) return const SizedBox.shrink();
        return Positioned.fill(
          child: Stack(
            children: [
              if (config.enableEdgeSwipe) const LxEdgeTrigger(),
              if (config.enableFloatingButton) const LxFabTrigger(),
            ],
          ),
        );
      },
    );
  }
}
