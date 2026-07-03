// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/repository/layerx_report_formatter.dart';

/// The "Problems" destination — a worst-first inbox of everything a tester
/// would actually report: crashes, errors, warnings, changed API responses,
/// and slow requests. The default landing surface of the redesigned shell.
class LxProblemsPane extends StatelessWidget {
  final List<LayerXLogEntry> logs;
  final ValueChanged<LayerXLogEntry> onInspect;

  const LxProblemsPane({
    super.key,
    required this.logs,
    required this.onInspect,
  });

  /// The minimum duration (ms) at which an otherwise-healthy entry is still
  /// surfaced as a problem — a slow request, even at success level. Delegates
  /// to [LayerXLogStore.slowRequestThresholdMs] so there is one knob for the
  /// whole viewer (inbox, badge, header, and settings tile all agree).
  static int get slowThresholdMs => LayerXLogStore.slowRequestThresholdMs;

  /// [LayerXLogStore.isProblemEntry] already includes the slow-request rule,
  /// so membership here is just that predicate. Sorted worst-first (fatal &
  /// error → warning → responseChanged-only → slow-only), ties broken by
  /// newest timestamp first.
  static List<LayerXLogEntry> problemsOf(List<LayerXLogEntry> logs) {
    final rows = logs.where(LayerXLogStore.isProblemEntry).toList()
      ..sort((a, b) {
        final rankCompare = _rankOf(a).compareTo(_rankOf(b));
        if (rankCompare != 0) return rankCompare;
        return b.timestamp.compareTo(a.timestamp);
      });
    return rows;
  }

  static bool _isSlow(LayerXLogEntry e) {
    final duration = LxKit.durationOf(e);
    return duration != null && duration >= slowThresholdMs;
  }

  /// Whether [e] is a problem for a reason other than the slow-request rule
  /// (level or a changed response). [LayerXLogStore.isProblemEntry] now
  /// folds the slow rule in, so this checks the non-slow conditions directly
  /// rather than re-testing the same entry's own membership.
  static bool _isProblemByLevelOrChange(LayerXLogEntry e) =>
      e.level == LayerXLogLevel.error ||
      e.level == LayerXLogLevel.fatal ||
      e.level == LayerXLogLevel.warning ||
      e.responseChanged;

  /// Lower rank sorts first (worse-first): fatal & error → warning →
  /// responseChanged-only → slow-only.
  static int _rankOf(LayerXLogEntry e) {
    if (e.level == LayerXLogLevel.fatal || e.level == LayerXLogLevel.error) {
      return 0;
    }
    if (e.level == LayerXLogLevel.warning) return 1;
    if (_isProblemByLevelOrChange(e)) {
      // Not fatal/error/warning but still a problem: responseChanged.
      return 2;
    }
    // Only reachable via the slow-request rule.
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final rows = problemsOf(logs);

    return rows.isEmpty
        ? LxKit.emptyState(
            Icons.inbox_outlined,
            'NO PROBLEMS YET',
            // Scope-honest: this tool records what happened; it can't retry
            // or fix anything on the tester's behalf.
            'Go use the app — anything that breaks shows up here. '
                "This records what happened; it can't retry for you.",
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (_, i) => LxKit.stagger(i, _problemRow(rows[i])),
          );
  }

  /// Resilient wrapper around [LayerXBlameEngine.analyze]: a card builder
  /// must never throw, so any exception is swallowed and treated as "no
  /// verdict" rather than crashing the inbox.
  static LayerXBlameInfo? _blameOf(LayerXLogEntry e) {
    try {
      return LayerXBlameEngine.analyze(e);
    } catch (_) {
      return null;
    }
  }

  Widget _problemRow(LayerXLogEntry e) {
    final rail = e.level.color;
    final duration = LxKit.durationOf(e);
    final isSlowOnly = !_isProblemByLevelOrChange(e) && _isSlow(e);
    final isFatal = e.level == LayerXLogLevel.fatal;
    final blame = _blameOf(e);
    final meta = [
      LayerXReportFormatter.relativeTime(e.timestamp),
      if (e.occurrenceCount > 1) '×${e.occurrenceCount}',
      if (isSlowOnly && duration != null) '⏱ ${duration}ms',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onInspect(e),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: isFatal
                ? LxKit.railCard(rail).copyWith(
                    color: LxTheme.accentRed.withValues(alpha: 0.08),
                  )
                : LxKit.railCard(rail),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LxKit.levelIcon(e.level), color: rail, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.message.split('\n').first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LxTheme.bodyPrimary.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: e.level == LayerXLogLevel.error ||
                                  e.level == LayerXLogLevel.fatal
                              ? LxTheme.accentRed
                              : LxTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LxKit.pill(e.source.label, e.source.color),
                if (blame != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    blame.responsibleParty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LxTheme.bodySecondary,
                  ),
                ],
                const SizedBox(height: 6),
                Text(meta,
                    style: LxTheme.monoSm.copyWith(color: LxTheme.textDim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
