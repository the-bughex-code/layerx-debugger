// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';

class LxNavItem {
  final IconData icon;
  final String label;
  final int? badge;
  final Color? badgeColor;
  const LxNavItem(this.icon, this.label, {this.badge, this.badgeColor});
}

/// The Neo Terminal debugger's persistent bottom navigation bar, with an
/// indicator that slides to the active destination.
class LxBottomNav extends StatelessWidget {
  final List<LxNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  const LxBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    // Map the active index to an alignment on [-1, 1] for the sliding bar.
    final align = n <= 1 ? 0.0 : (index / (n - 1)) * 2 - 1;

    return Container(
      decoration: const BoxDecoration(
        color: LxTheme.surface,
        border: Border(top: BorderSide(color: LxTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Sliding indicator track ────────────────────────────────────
            SizedBox(
              height: 2,
              child: AnimatedAlign(
                alignment: Alignment(align, 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: LxTheme.accent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: LxTheme.glowShadow(LxTheme.accent, spread: 4),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: _item(items[i], i)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(LxNavItem item, int i) {
    final active = index == i;
    final color = active ? LxTheme.accent : LxTheme.textSecondary;
    return InkWell(
      onTap: () => onSelect(i),
      child: Padding(
        padding: const EdgeInsets.only(top: 9, bottom: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: active ? 1.12 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(item.icon, color: color, size: 21),
                ),
                if ((item.badge ?? 0) > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: item.badgeColor ?? LxTheme.accentRed,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.badge! > 99 ? '99+' : '${item.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontFamily: 'monospace',
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(item.label.toLowerCase()),
            ),
          ],
        ),
      ),
    );
  }
}
