// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

/// Premium dark solution / suggested-fix card.
class LxSolutionCard extends StatelessWidget {
  final String solution;
  final String sourceLabel;

  const LxSolutionCard({
    super.key,
    required this.solution,
    required this.sourceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: LxTheme.accentAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LxTheme.accentAmber.withValues(alpha: 0.35)),
        boxShadow: LxTheme.glowShadow(LxTheme.accentAmber, spread: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LxTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_outlined,
                    color: LxTheme.accentAmber,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text('SUGGESTED FIX', style: LxTheme.sectionLabel.copyWith(color: LxTheme.accentAmber)),
              ],
            ),
            const SizedBox(height: 14),

            // ── Solution text ────────────────────────────────────────────────
            Text(
              solution,
              style: LxTheme.bodyPrimary.copyWith(height: 1.6),
            ),
            const SizedBox(height: 14),

            // ── Source footer ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LxTheme.accentAmber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'source: $sourceLabel',
                  style: LxTheme.monoSm.copyWith(color: LxTheme.accentAmber.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
