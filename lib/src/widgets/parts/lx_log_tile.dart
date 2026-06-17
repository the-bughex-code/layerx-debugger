// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_source_chip.dart';

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
    final isToday =
        ts.year == now.year && ts.month == now.month && ts.day == now.day;
    final isYesterday =
        ts.year == now.year && ts.month == now.month && ts.day == now.day - 1;
    final datePrefix = isToday
        ? ''
        : isYesterday
            ? 'Yest · '
            : DateFormat('d MMM · ').format(ts);
    final formattedTime = '$datePrefix${DateFormat('HH:mm:ss').format(ts)}';
    final bgTint = log.level.backgroundColor ?? Colors.white;

    var journeyPreview = '';
    if (log.journey.isNotEmpty) {
      final steps = log.journey;
      final count = steps.length;
      final previewSteps = steps.sublist(count > 3 ? count - 3 : 0);
      journeyPreview = previewSteps.map((s) => s.title).join(' → ');
    }

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        color: bgTint,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: log.level.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.level.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.level.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            LxSourceChip(source: log.source),
                            const Spacer(),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (log.screenName != null ||
                            log.methodName != null) ...[
                          Text(
                            '${log.screenName ?? 'UnknownScreen'} → ${log.methodName ?? 'unknownMethod'}()',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          log.message,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (journeyPreview.isNotEmpty)
                              Expanded(
                                child: Text(
                                  journeyPreview,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(width: 4),
                            if (log.responseChanged)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.swap_horiz,
                                        size: 9, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'API CHANGED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 4),
                            if (log.occurrenceCount > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '×${log.occurrenceCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 14, color: Colors.grey.shade400),
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
    );
  }
}
