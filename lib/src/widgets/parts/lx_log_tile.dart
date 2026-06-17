// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_source_chip.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

class LxLogTile extends StatelessWidget {
  final LayerXLogEntry log;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const LxLogTile({
    super.key,
    required this.log,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ts = log.timestamp;
    final isToday = ts.year == now.year && ts.month == now.month && ts.day == now.day;
    final isYesterday = ts.year == now.year && ts.month == now.month && ts.day == now.day - 1;
    final datePrefix = isToday
        ? ''
        : isYesterday
            ? 'Yest · '
            : DateFormat('d MMM · ').format(ts);
    final formattedTime = '$datePrefix${DateFormat('HH:mm:ss').format(ts)}';

    var journeyPreview = '';
    if (log.journey.isNotEmpty) {
      final steps = log.journey;
      final count = steps.length;
      final previewSteps = steps.sublist(count > 3 ? count - 3 : 0);
      journeyPreview = previewSteps.map((s) => s.title).join(' → ');
    }

    final levelColor = log.level.color;

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: LxTheme.accentRed.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: LxTheme.accentRed, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: LxTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: LxTheme.border),
            boxShadow: [
              BoxShadow(
                color: levelColor.withValues(alpha: 0.06),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Level accent bar ──────────────────────────────────────
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: levelColor,
                      boxShadow: [
                        BoxShadow(
                          color: levelColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),

                  // ── Content ───────────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Top row: level + source + time ────────────────
                          Row(
                            children: [
                              // Level dot + label
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: levelColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: levelColor.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                log.level.label.toUpperCase(),
                                style: TextStyle(
                                  color: levelColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              LxSourceChip(source: log.source),
                              const Spacer(),
                              Text(
                                formattedTime,
                                style: LxTheme.monoSm,
                              ),
                            ],
                          ),

                          const SizedBox(height: 7),

                          // ── Screen → method ───────────────────────────────
                          if (log.screenName != null || log.methodName != null) ...[
                            Text(
                              '${log.screenName ?? 'UnknownScreen'}  ›  ${log.methodName ?? 'unknown'}()',
                              style: LxTheme.monoSm.copyWith(
                                color: LxTheme.textSecondary,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                          ],

                          // ── Message ───────────────────────────────────────
                          Text(
                            log.message,
                            style: LxTheme.bodyPrimary.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 7),

                          // ── Bottom row: journey + badges + arrow ──────────
                          Row(
                            children: [
                              if (journeyPreview.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    journeyPreview,
                                    style: LxTheme.monoSm.copyWith(
                                      color: LxTheme.textDim,
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              if (log.responseChanged)
                                _badge('API CHANGED', LxTheme.accentOrange),
                              if (log.occurrenceCount > 1) ...[
                                const SizedBox(width: 4),
                                _badge('×${log.occurrenceCount}', LxTheme.accentAmber),
                              ],
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: LxTheme.textDim,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
