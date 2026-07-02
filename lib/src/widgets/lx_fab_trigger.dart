// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';

class LxFabTrigger extends StatefulWidget {
  const LxFabTrigger({super.key});

  @override
  State<LxFabTrigger> createState() => _LxFabTriggerState();
}

class _LxFabTriggerState extends State<LxFabTrigger>
    with TickerProviderStateMixin {
  // Static so the dragged position and one-time mount animation survive the
  // overlay entry being re-inserted on navigation (see LayerXOverlayInstaller).
  static Offset _offset = const Offset(-1, -1);
  static bool _mountedOnce = false;
  bool _isDragging = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _mountCtrl;
  late final Animation<double> _mountAnim;

  @override
  void initState() {
    super.initState();

    // Glow pulse ring
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Slide-in on mount
    _mountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _mountAnim = CurvedAnimation(parent: _mountCtrl, curve: Curves.elasticOut);
    // Only play the elastic entrance the first time; on later re-inserts (route
    // changes) the FAB should simply reappear where the user left it.
    if (_mountedOnce) {
      _mountCtrl.value = 1.0;
    } else {
      _mountCtrl.forward();
      _mountedOnce = true;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mountCtrl.dispose();
    super.dispose();
  }

  void _openLogs(BuildContext context) {
    final nav = LayerXDebugger.findNavigator(context);
    if (nav != null) {
      nav.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, __) => const LxDebuggerShell(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 380),
        ),
      );
    } else {
      try {
        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, animation, __) => const LxDebuggerShell(),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 380),
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    if (_offset.dx == -1 && _offset.dy == -1) {
      _offset = Offset(screenSize.width - 72, screenSize.height - 148);
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: ScaleTransition(
        scale: _mountAnim,
        child: ValueListenableBuilder<List<LayerXLogEntry>>(
          valueListenable: LayerXLogStore.logsNotifier,
          builder: (context, logs, _) {
            final errorCount = LayerXLogStore.errorCount;
            final totalCount = logs.length;
            final hasErrors = errorCount > 0;
            final badgeCount = hasErrors ? errorCount : totalCount;
            final accentColor = hasErrors ? LxTheme.accentRed : LxTheme.accent;

            return GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  var newX = _offset.dx + details.delta.dx;
                  var newY = _offset.dy + details.delta.dy;
                  newX = newX.clamp(10.0, screenSize.width - 70.0);
                  newY = newY.clamp(50.0, screenSize.height - 100.0);
                  _offset = Offset(newX, newY);
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              onTap: () => _openLogs(context),
              onLongPress: () => _showQuickMenu(context),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // ── Outer pulse ring ────────────────────────────────
                      if (!_isDragging)
                        Container(
                          width: 56 + (_pulseAnim.value * 10),
                          height: 56 + (_pulseAnim.value * 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withValues(
                                  alpha: (1.0 - _pulseAnim.value) * 0.5),
                              width: 1.5,
                            ),
                          ),
                        ),

                      // ── Main FAB body ───────────────────────────────────
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LxTheme.surface,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.12),
                              blurRadius: 32,
                              spreadRadius: 0,
                            ),
                            const BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: hasErrors ? math.pi / 12 : 0,
                          child: Icon(
                            hasErrors ? Icons.bug_report : Icons.pest_control_outlined,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                      ),

                      // ── Count badge ─────────────────────────────────────
                      if (badgeCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: LxTheme.bg, width: 1.5),
                              boxShadow: LxTheme.glowShadow(accentColor, spread: 3),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                badgeCount > 99 ? '99+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showQuickMenu(BuildContext context) {
    final nav = LayerXDebugger.findNavigator(context);
    final targetContext = nav?.context ?? context;
    showModalBottomSheet<void>(
      context: targetContext,
      useRootNavigator: nav == null,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: LxTheme.surfaceAlt,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(top: BorderSide(color: LxTheme.border)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: LxTheme.borderActive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _menuTile(
                ctx,
                icon: Icons.terminal_outlined,
                color: LxTheme.accent,
                label: 'View Logs',
                onTap: () { Navigator.pop(ctx); _openLogs(context); },
              ),
              _menuTile(
                ctx,
                icon: Icons.copy_outlined,
                color: LxTheme.accentGreen,
                label: 'Export & Copy All',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  await LayerXLogStore.copyExportToClipboard();
                  messenger.showSnackBar(
                    LxTheme.snackBar('All logs copied to clipboard ✓'),
                  );
                },
              ),
              _menuTile(
                ctx,
                icon: Icons.delete_sweep_outlined,
                color: LxTheme.accentRed,
                label: 'Clear All Logs',
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  LayerXLogStore.clear();
                  messenger.showSnackBar(LxTheme.snackBar('Logs cleared'));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label, style: LxTheme.bodyPrimary.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
