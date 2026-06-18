// Internal viewer UI kit — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';

/// Shared helpers and small reusable widgets for the redesigned debugger shell.
abstract final class LxKit {
  // ── Classification ─────────────────────────────────────────────────────────
  static bool isNetwork(LayerXLogEntry e) => e.endpoint != null;

  static int? durationOf(LayerXLogEntry e) {
    final v = e.extras['duration_ms'];
    return v is int ? v : null;
  }

  static bool isProblem(LayerXLogEntry e) =>
      e.level == LayerXLogLevel.error ||
      e.level == LayerXLogLevel.fatal ||
      e.level == LayerXLogLevel.warning ||
      e.responseChanged;

  static Color methodColor(String? method) {
    switch ((method ?? '').toUpperCase()) {
      case 'GET':
        return LxTheme.accentGreen;
      case 'POST':
        return LxTheme.accentBlue;
      case 'PUT':
        return LxTheme.accentAmber;
      case 'PATCH':
        return LxTheme.accentPurple;
      case 'DELETE':
        return LxTheme.accentRed;
      default:
        return LxTheme.accentCyan;
    }
  }

  static Color statusColor(int? code) {
    if (code == null) return LxTheme.textDim;
    if (code >= 500) return LxTheme.accentRed;
    if (code >= 400) return LxTheme.accentOrange;
    if (code >= 300) return LxTheme.accent;
    return LxTheme.accentGreen;
  }

  static IconData levelIcon(LayerXLogLevel level) {
    switch (level) {
      case LayerXLogLevel.verbose:
      case LayerXLogLevel.debug:
        return Icons.code;
      case LayerXLogLevel.info:
        return Icons.info_outline;
      case LayerXLogLevel.success:
        return Icons.check_circle_outline;
      case LayerXLogLevel.warning:
        return Icons.warning_amber_rounded;
      case LayerXLogLevel.error:
        return Icons.error_outline;
      case LayerXLogLevel.fatal:
        return Icons.local_fire_department_outlined;
    }
  }

  static String shortPath(String? endpoint) {
    if (endpoint == null) return '';
    try {
      final uri = Uri.parse(endpoint);
      return uri.path.isEmpty ? endpoint : uri.path;
    } catch (_) {
      return endpoint;
    }
  }

  static String clockTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  // ── Reusable widgets ─────────────────────────────────────────────────────────
  static Widget sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text, style: LxTheme.sectionLabel),
      );

  static Widget pill(String text, Color color, {bool solid = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: LxTheme.pill(color),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// A card with a colored left rail — used for issue/problem rows.
  static BoxDecoration railCard(Color rail) => BoxDecoration(
        color: LxTheme.surface,
        border: Border(
          left: BorderSide(color: rail, width: 3),
          top: BorderSide(color: LxTheme.border),
          right: BorderSide(color: LxTheme.border),
          bottom: BorderSide(color: LxTheme.border),
        ),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
      );

  static Widget emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LxTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LxTheme.border),
            ),
            child: Icon(icon, size: 36, color: LxTheme.textDim),
          ),
          const SizedBox(height: 18),
          Text(title, style: LxTheme.sectionLabel),
          const SizedBox(height: 8),
          Text(subtitle, style: LxTheme.bodySecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
