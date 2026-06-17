// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/layerx_debug_config.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';

class LxEdgeTrigger extends StatelessWidget {
  const LxEdgeTrigger({super.key});

  void _open(BuildContext context) {
    LayerXDebugger.openViewer(context);
  }

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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (isLeft || isRight)
            ? (details) {
                if (isRight && details.primaryDelta! < -8) {
                  _open(context);
                } else if (isLeft && details.primaryDelta! > 8) {
                  _open(context);
                }
              }
            : null,
        onVerticalDragUpdate: isBottom
            ? (details) {
                if (details.primaryDelta! < -8) _open(context);
              }
            : null,
        child: Container(
          width: width,
          height: height,
          color: Colors.transparent,
          child: Align(
            alignment: isLeft
                ? Alignment.centerLeft
                : (isRight ? Alignment.centerRight : Alignment.bottomCenter),
            child: Container(
              width: isBottom ? double.infinity : 1.5,
              height: isBottom ? 1.5 : double.infinity,
              decoration: BoxDecoration(
                color: LxTheme.accentBlue.withValues(alpha: 0.3),
                boxShadow: LxTheme.glowShadow(LxTheme.accentBlue, spread: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
