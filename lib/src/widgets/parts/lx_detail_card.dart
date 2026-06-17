// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

/// Premium dark detail card with uppercase section label.
class LxDetailCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? accentColor;

  const LxDetailCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: LxTheme.card(glowColor: accentColor),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (accentColor != null) ...[
                      Container(
                        width: 3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(title.toUpperCase(), style: LxTheme.sectionLabel),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
