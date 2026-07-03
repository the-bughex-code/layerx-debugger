// Internal viewer UI kit — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

/// Shared helpers and small reusable widgets for the redesigned debugger shell.
abstract final class LxKit {
  // ── Classification ─────────────────────────────────────────────────────────
  static bool isNetwork(LayerXLogEntry e) => e.endpoint != null;

  static int? durationOf(LayerXLogEntry e) {
    final v = e.extras['duration_ms'];
    return v is int ? v : null;
  }

  static bool isProblem(LayerXLogEntry e) => LayerXLogStore.isProblemEntry(e);

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

  /// A one-line, copyable summary of an entry for the per-row copy action.
  static String copySummary(LayerXLogEntry e) {
    final loc =
        e.sourceFile != null ? ' (${e.sourceFile}:${e.sourceLine ?? '?'})' : '';
    return '[${clockTime(e.timestamp)}] [${e.level.label}] '
        '[${e.category.label}] ${e.message}$loc';
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
  ///
  /// Corners are square: Flutter forbids a [borderRadius] on a [Border] whose
  /// sides have non-uniform colors (the rail differs from the other sides), and
  /// crisp left-accent rows suit the Neo Terminal look anyway.
  static BoxDecoration railCard(Color rail) => BoxDecoration(
        color: LxTheme.surface,
        border: Border(
          left: BorderSide(color: rail, width: 3),
          top: const BorderSide(color: LxTheme.border),
          right: const BorderSide(color: LxTheme.border),
          bottom: const BorderSide(color: LxTheme.border),
        ),
      );

  /// Wraps [child] in a staggered fade + slide-up entrance animation, used by
  /// the list panes. The delay grows with [index] but is capped so long lists
  /// stay snappy and never feel laggy.
  static Widget stagger(int index, Widget child) {
    final delayMs = (index * 28).clamp(0, 240);
    return TweenAnimationBuilder<double>(
      key: ValueKey('lx_stagger_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: c,
        ),
      ),
      child: child,
    );
  }

  static Widget emptyState(IconData icon, String title, String subtitle,
      {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            Text(subtitle,
                style: LxTheme.bodySecondary, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 10),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// The one-tap escape hatch offered by filtered-empty states.
  static Widget clearFiltersButton(VoidCallback onClear) => TextButton(
        onPressed: onClear,
        style: TextButton.styleFrom(foregroundColor: LxTheme.accent),
        child: const Text('Clear filters',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  /// A slim "Showing N of M" header rendered above a list whose filters hide
  /// some (but not all) rows, with a one-tap "Show all" back to everything —
  /// so a partially filtered view never masquerades as the full picture.
  static Widget filterSummaryBar(int shown, int total, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LxTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 13, color: LxTheme.textDim),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Showing $shown of $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LxTheme.caption,
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: LxTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Show all',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
