import 'package:flutter/material.dart';

import '../../models/layerx_log_source.dart';

/// A small colored chip showing a log entry's [LayerXLogSource].
class LxSourceChip extends StatelessWidget {
  /// The source to display.
  final LayerXLogSource source;

  /// Creates a source chip.
  const LxSourceChip({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: source.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: source.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        source.label,
        style: TextStyle(
          color: source.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
