// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_journey_step.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

/// Premium dark journey timeline card.
class LxJourneyTimeline extends StatelessWidget {
  final List<LayerXJourneyStep> journey;
  const LxJourneyTimeline({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    if (journey.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: LxTheme.card(glowColor: LxTheme.accentPurple),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: LxTheme.accentPurple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('EXECUTION JOURNEY', style: LxTheme.sectionLabel),
                const Spacer(),
                Text(
                  '${journey.length} steps',
                  style: LxTheme.monoSm,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Steps ────────────────────────────────────────────────────────
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: journey.length,
              itemBuilder: (context, index) {
                final step = journey[index];
                final isLast = index == journey.length - 1;
                final isError = step.type == 'error';
                final color = _stepColor(step.type);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Timeline spine ─────────────────────────────────────
                      Column(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.12),
                              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                              boxShadow: LxTheme.glowShadow(color, spread: 3),
                            ),
                            child: Center(
                              child: Icon(_stepIcon(step.type), size: 11, color: color),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: isError
                                    ? LxTheme.accentRed.withValues(alpha: 0.4)
                                    : LxTheme.border,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // ── Step content ────────────────────────────────────────
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isError
                                ? LxTheme.accentRed.withValues(alpha: 0.05)
                                : LxTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isError
                                  ? LxTheme.accentRed.withValues(alpha: 0.3)
                                  : LxTheme.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      step.title,
                                      style: LxTheme.labelBold.copyWith(
                                        color: isError ? LxTheme.accentRed : color,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm:ss.SSS').format(step.timestamp),
                                    style: LxTheme.monoSm,
                                  ),
                                ],
                              ),
                              if (step.description != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  step.description!,
                                  style: LxTheme.bodySecondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _stepColor(String? type) {
    switch (type) {
      case 'ui': return LxTheme.accentPurple;
      case 'controller': return LxTheme.accentBlue;
      case 'service': return LxTheme.accentGreen;
      case 'repository': return const Color(0xFF2DD4BF);
      case 'network': return LxTheme.accentCyan;
      case 'error': return LxTheme.accentRed;
      default: return LxTheme.textSecondary;
    }
  }

  IconData _stepIcon(String? type) {
    switch (type) {
      case 'ui': return Icons.phone_android;
      case 'controller': return Icons.gamepad_outlined;
      case 'service': return Icons.miscellaneous_services_outlined;
      case 'repository': return Icons.storage_outlined;
      case 'network': return Icons.cloud_outlined;
      case 'error': return Icons.error_outline;
      default: return Icons.circle;
    }
  }
}
