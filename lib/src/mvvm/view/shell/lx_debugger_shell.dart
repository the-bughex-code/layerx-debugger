// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
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
            body: IndexedStack(index: _index, children: panes),
            bottomNavigationBar: LxBottomNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              items: [
                const LxNavItem(Icons.dashboard_outlined, 'Dashboard'),
                LxNavItem(Icons.swap_vert, 'Network',
                    badge: networkCount, badgeColor: LxTheme.accentBlue),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_titles[_index],
                  style: LxTheme.bodyPrimary
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${LayerXDebugger.config.appName} · $total logs',
                  style: LxTheme.monoSm),
            ],
          ),
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
