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

/// The redesigned debugger's persistent bottom navigation bar.
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1014),
        border: Border(top: BorderSide(color: LxTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _item(items[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _item(LxNavItem item, int i) {
    final active = index == i;
    final color = active ? LxTheme.accentBlue : LxTheme.textSecondary;
    return InkWell(
      onTap: () => onSelect(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, color: color, size: 22),
                if ((item.badge ?? 0) > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: item.badgeColor ?? LxTheme.accentRed,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.badge! > 99 ? '99+' : '${item.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
