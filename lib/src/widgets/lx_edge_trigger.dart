// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/layerx_debug_config.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';

class LxEdgeTrigger extends StatefulWidget {
  const LxEdgeTrigger({super.key});

  @override
  State<LxEdgeTrigger> createState() => _LxEdgeTriggerState();
}

class _LxEdgeTriggerState extends State<LxEdgeTrigger> {
  /// One swipe must open the viewer at most once. A fast swipe delivers many
  /// drag updates past the 8px threshold, and an unlatched handler used to
  /// push a debugger shell for every one of them — stacked shells that made
  /// the back button appear broken. Latched on first trigger, re-armed when
  /// the gesture ends.
  bool _dragConsumed = false;

  void _open(BuildContext context) {
    LayerXDebugger.openViewer(context);
  }

  void _openOnce(BuildContext context) {
    if (_dragConsumed) return;
    _dragConsumed = true;
    _open(context);
  }

  void _rearm() => _dragConsumed = false;

  @override
  Widget build(BuildContext context) {
    final zone = LayerXDebugger.config.edgeSwipeZone;
    final isRight = zone == LayerXEdgeZone.right;
    final isLeft = zone == LayerXEdgeZone.left;
    final isBottom = zone == LayerXEdgeZone.bottom;

    final width = isBottom ? double.infinity : 20.0;
    final height = isBottom ? 20.0 : double.infinity;

    return Positioned(
      left: isLeft ? 0 : null,
      right: isRight ? 0 : null,
      bottom: 0,
      top: isBottom ? null : 0,
      child: Semantics(
        button: true,
        label: 'Open the debugger',
        // A screen-reader tap is the accessible equivalent of the edge swipe
        // (which a reader cannot perform).
        onTap: () => _open(context),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (isLeft || isRight)
              ? (details) {
                  if (isRight && details.primaryDelta! < -8) {
                    _openOnce(context);
                  } else if (isLeft && details.primaryDelta! > 8) {
                    _openOnce(context);
                  }
                }
              : null,
          onHorizontalDragEnd: (isLeft || isRight) ? (_) => _rearm() : null,
          onHorizontalDragCancel: (isLeft || isRight) ? _rearm : null,
          onVerticalDragUpdate: isBottom
              ? (details) {
                  if (details.primaryDelta! < -8) _openOnce(context);
                }
              : null,
          onVerticalDragEnd: isBottom ? (_) => _rearm() : null,
          onVerticalDragCancel: isBottom ? _rearm : null,
          child: Container(
            width: width,
            height: height,
            color: Colors.transparent,
            child: Align(
              alignment: isLeft
                  ? Alignment.centerLeft
                  : (isRight ? Alignment.centerRight : Alignment.bottomCenter),
              // §4.5 / UX P3: a visible rounded grab handle (~4×48) centered on
              // the edge — replaces the old barely-there glow hairline. Same
              // swipe gesture; the handle just makes the affordance findable.
              child: Container(
                margin: const EdgeInsets.all(3),
                width: isBottom ? 48.0 : 4.0,
                height: isBottom ? 4.0 : 48.0,
                decoration: BoxDecoration(
                  color: LxTheme.borderActive,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
