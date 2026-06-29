// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_dashboard_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_network_pane.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_bottom_nav.dart';

/// The redesigned in-app debugger: a bottom-navigation shell hosting the
/// Dashboard, Network, Console and Inspector destinations.
///
/// Replaces the legacy single-list `LxLogListScreen` as the viewer entry point.
class LxDebuggerShell extends StatefulWidget {
  const LxDebuggerShell({super.key});

  @override
  State<LxDebuggerShell> createState() => _LxDebuggerShellState();
}

class _LxDebuggerShellState extends State<LxDebuggerShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Network', 'Console', 'Inspector'];

  @override
  void initState() {
    super.initState();
    LayerXViewerState.markOpened();
  }

  @override
  void dispose() {
    LayerXViewerState.markClosed();
    super.dispose();
  }

  void _inspect(LayerXLogEntry log) {
    LayerXViewerState.selected.value = log;
    setState(() => _index = 3);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: ValueListenableBuilder<List<LayerXLogEntry>>(
        valueListenable: LayerXLogStore.logsNotifier,
        builder: (context, logs, _) {
          final errors = logs
              .where((l) =>
                  l.level == LayerXLogLevel.error ||
                  l.level == LayerXLogLevel.fatal)
              .length;
          final networkCount = logs.where((l) => l.endpoint != null).length;

          final panes = [
            LxDashboardPane(logs: logs, onInspect: _inspect),
            LxNetworkPane(logs: logs, onInspect: _inspect),
            LxConsolePane(logs: logs, onInspect: _inspect),
            ValueListenableBuilder<LayerXLogEntry?>(
              valueListenable: LayerXViewerState.selected,
              builder: (_, sel, __) => LxInspectorPane(log: sel),
            ),
          ];

          return Scaffold(
            backgroundColor: LxTheme.bg,
            appBar: _appBar(context, logs.length, errors),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // Expand children to the full body size during the cross-fade so a
              // pane never gets loose constraints mid-transition (which would
              // collapse its rows to content width and overflow).
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.012),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: panes[_index],
              ),
            ),
            bottomNavigationBar: LxBottomNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              items: [
                const LxNavItem(Icons.dashboard_outlined, 'Dashboard'),
                LxNavItem(Icons.swap_vert, 'Network',
                    badge: networkCount, badgeColor: LxTheme.accent),
                LxNavItem(Icons.terminal, 'Console',
                    badge: errors, badgeColor: LxTheme.accentRed),
                const LxNavItem(Icons.travel_explore, 'Inspector'),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, int total, int errors) {
    return AppBar(
      backgroundColor: LxTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: LxTheme.textSecondary, size: 20),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: LxTheme.border),
      ),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: errors > 0 ? LxTheme.accentRed : LxTheme.accentGreen,
              boxShadow: LxTheme.glowShadow(
                  errors > 0 ? LxTheme.accentRed : LxTheme.accentGreen,
                  spread: 3),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5, height: 1.2),
                children: [
                  const TextSpan(
                      text: 'layerx',
                      style: TextStyle(
                          color: LxTheme.accent, fontWeight: FontWeight.w700)),
                  const TextSpan(
                      text: '@dbg ',
                      style: TextStyle(color: LxTheme.textSecondary)),
                  TextSpan(
                      text: '~/${_titles[_index].toLowerCase()} ',
                      style: const TextStyle(color: LxTheme.accentCyan)),
                  const TextSpan(
                      text: r'$ ',
                      style: TextStyle(color: LxTheme.textSecondary)),
                  TextSpan(
                      text: '$total',
                      style: const TextStyle(
                          color: LxTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const TextSpan(
                      text: ' logs',
                      style: TextStyle(color: LxTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const _LxBlinkingCursor(),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_all_outlined, size: 20),
          tooltip: 'Export all',
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await LayerXLogStore.copyExportToClipboard();
            messenger.showSnackBar(LxTheme.snackBar('Logs copied ✓'));
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined,
              size: 20, color: LxTheme.accentRed),
          tooltip: 'Clear all',
          onPressed: () {
            LayerXLogStore.clear();
            LayerXViewerState.selected.value = null;
          },
        ),
      ],
    );
  }
}

/// A small blinking block cursor that gives the header its live-terminal feel.
class _LxBlinkingCursor extends StatefulWidget {
  const _LxBlinkingCursor();

  @override
  State<_LxBlinkingCursor> createState() => _LxBlinkingCursorState();
}

class _LxBlinkingCursorState extends State<_LxBlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(_BlinkTween()),
      child: Container(
        width: 7,
        height: 15,
        decoration: BoxDecoration(
          color: LxTheme.accent,
          borderRadius: BorderRadius.circular(1),
          boxShadow: LxTheme.glowShadow(LxTheme.accent, spread: 3),
        ),
      ),
    );
  }
}

/// Square-wave opacity: solid for the first half of the cycle, hidden for the
/// second — a classic terminal cursor blink rather than a smooth fade.
class _BlinkTween extends Animatable<double> {
  @override
  double transform(double t) => t < 0.5 ? 1.0 : 0.0;
}
