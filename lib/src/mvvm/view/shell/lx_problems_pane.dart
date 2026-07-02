// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';
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
  /// surfaced as a problem — a slow request, even at success level.
  static const int slowThresholdMs = 800;

  /// The union of [LayerXLogStore.isProblemEntry] and the slow-request rule,
  /// sorted worst-first (fatal & error → warning → responseChanged-only →
  /// slow-only), ties broken by newest timestamp first.
  static List<LayerXLogEntry> problemsOf(List<LayerXLogEntry> logs) {
    final rows = logs.where(_isProblemRow).toList()
      ..sort((a, b) {
        final rankCompare = _rankOf(a).compareTo(_rankOf(b));
        if (rankCompare != 0) return rankCompare;
        return b.timestamp.compareTo(a.timestamp);
      });
    return rows;
  }

  static bool _isProblemRow(LayerXLogEntry e) =>
      LayerXLogStore.isProblemEntry(e) || _isSlow(e);

  static bool _isSlow(LayerXLogEntry e) {
    final duration = LxKit.durationOf(e);
    return duration != null && duration >= slowThresholdMs;
  }

  /// Lower rank sorts first (worse-first): fatal & error → warning →
  /// responseChanged-only → slow-only.
  static int _rankOf(LayerXLogEntry e) {
    if (e.level == LayerXLogLevel.fatal || e.level == LayerXLogLevel.error) {
      return 0;
    }
    if (e.level == LayerXLogLevel.warning) return 1;
    if (LayerXLogStore.isProblemEntry(e)) {
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
            'Go use the app — anything that breaks will show up here.',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (_, i) => LxKit.stagger(i, _problemRow(rows[i])),
          );
  }

  Widget _problemRow(LayerXLogEntry e) {
    final rail = e.level.color;
    final duration = LxKit.durationOf(e);
    final isSlowOnly = !LayerXLogStore.isProblemEntry(e) && _isSlow(e);
    final meta = [
      LayerXReportFormatter.relativeTime(e.timestamp),
      e.source.label,
      if (e.occurrenceCount > 1) '×${e.occurrenceCount}',
    ].join(' · ');

    return InkWell(
      onTap: () => onInspect(e),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LxTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.only(right: 11, top: 1),
              decoration: BoxDecoration(
                color: rail,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(LxKit.levelIcon(e.level), color: rail, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.message.split('\n').first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LxTheme.bodyPrimary.copyWith(
                      fontSize: 12.5,
                      color: e.level.color == LxTheme.accentRed
                          ? LxTheme.accentRed
                          : LxTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: LxTheme.monoSm.copyWith(color: LxTheme.textDim)),
                  if (isSlowOnly && duration != null) ...[
                    const SizedBox(height: 2),
                    Text('⏱ ${duration}ms',
                        style: LxTheme.monoSm
                            .copyWith(color: LxTheme.accentAmber)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
