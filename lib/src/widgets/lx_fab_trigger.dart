// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
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
  // §4.5 / UX P3: the trigger is a labeled pill ("Report a bug"), not an
  // anonymous round FAB. The pill is width-capped so a 320px screen fits it
  // with margins; on narrower screens it shrinks and the label ellipsizes.
  static const double _pillMaxWidth = 170;
  static const double _pillHeight = 48;

  // Static so the dragged position and one-time mount animation survive the
  // overlay entry being re-inserted on navigation (see LayerXOverlayInstaller).
  // `dx` is the distance from the RIGHT screen edge (the pill is right-anchored
  // so its resting margin stays exact regardless of the label's actual width);
  // `dy` is the distance from the top.
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
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
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
                ).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
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
    final pillWidth = math.min(_pillMaxWidth, screenSize.width - 24);
    final maxRight = math.max(8.0, screenSize.width - pillWidth - 8);
    final maxTop = math.max(50.0, screenSize.height - 100.0);
    if (_offset.dx == -1 && _offset.dy == -1) {
      // Rest: right-aligned with a 16px margin, above the home-bar region.
      _offset = Offset(16, screenSize.height - 148);
    }
    // Re-clamp the remembered position into the *current* screen so the pill
    // stays fully reachable after a rotation or a re-insert on a narrower
    // (e.g. 320px) screen.
    _offset = Offset(
      _offset.dx.clamp(8.0, maxRight),
      _offset.dy.clamp(50.0, maxTop),
    );

    return Positioned(
      right: _offset.dx,
      top: _offset.dy,
      child: ScaleTransition(
        scale: _mountAnim,
        child: ValueListenableBuilder<List<LayerXLogEntry>>(
          valueListenable: LayerXLogStore.logsNotifier,
          builder: (context, logs, _) {
            final hasErrors = LayerXLogStore.errorCount > 0;
            final badgeCount = LayerXLogStore.openProblemCount;
            final accentColor = hasErrors ? LxTheme.accentRed : LxTheme.accent;

            // The pill is a labeled button for screen readers: one clean
            // node whose explicit label wins over the inner 'Report a bug'
            // Text (excluded), with a semantic tap that opens the debugger.
            // The real drag/tap/long-press gestures stay on the GestureDetector
            // below (ExcludeSemantics hides only semantics, not pointers).
            return Semantics(
              container: true,
              button: true,
              label: 'Report a bug — open the debugger',
              onTap: () => _openLogs(context),
              child: ExcludeSemantics(
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      // dx measures from the right edge, so it moves opposite to
                      // the finger's horizontal delta.
                      final newRight =
                          (_offset.dx - details.delta.dx).clamp(8.0, maxRight);
                      final newTop =
                          (_offset.dy + details.delta.dy).clamp(50.0, maxTop);
                      _offset = Offset(newRight, newTop);
                    });
                  },
                  onPanEnd: (_) => setState(() => _isDragging = false),
                  onTap: () => _openLogs(context),
                  onLongPress: () => _showQuickMenu(context),
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      final inset = _pulseAnim.value * 5;
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // ── Outer pulse ring ────────────────────────────────
                          if (!_isDragging)
                            Positioned(
                              left: -inset,
                              top: -inset,
                              right: -inset,
                              bottom: -inset,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      _pillHeight / 2 + inset),
                                  border: Border.all(
                                    color: accentColor.withValues(
                                        alpha: (1.0 - _pulseAnim.value) * 0.5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                          // ── Main pill body: bug icon + static label ─────────
                          // (§4.5 / P3 task 5: the badge carries the count, the
                          // label never changes.)
                          Container(
                            width: pillWidth,
                            height: _pillHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(_pillHeight / 2),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.rotate(
                                  angle: hasErrors ? math.pi / 12 : 0,
                                  child: Icon(
                                    hasErrors
                                        ? Icons.bug_report
                                        : Icons.pest_control_outlined,
                                    color: accentColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'Report a bug',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: LxTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Count badge ─────────────────────────────────────
                          if (badgeCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: LxTheme.bg, width: 1.5),
                                  boxShadow: LxTheme.glowShadow(accentColor,
                                      spread: 3),
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 18, minHeight: 18),
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
                ),
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
                onTap: () {
                  Navigator.pop(ctx);
                  _openLogs(context);
                },
              ),
              _menuTile(
                ctx,
                icon: Icons.copy_outlined,
                color: LxTheme.accentGreen,
                label: 'Export & Copy All',
                onTap: () {
                  Navigator.pop(ctx);
                  LxCopy.copyExport(context);
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
            Text(label,
                style:
                    LxTheme.bodyPrimary.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
