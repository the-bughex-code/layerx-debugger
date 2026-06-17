// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';

/// Premium dark source chip — monospace label with colored glow border.
class LxSourceChip extends StatelessWidget {
  final LayerXLogSource source;
  const LxSourceChip({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final c = source.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        source.label.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
