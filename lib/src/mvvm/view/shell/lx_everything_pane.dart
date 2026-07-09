// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_dashboard_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_network_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';

enum _EverythingTab { console, network, dashboard }

/// The "Everything" destination — the demoted developer surface hosting the
/// full Console / Network / Dashboard panes behind a small sub-switch.
/// Console is the default tab: it's the closest to "all logs".
class LxEverythingPane extends StatefulWidget {
  final List<LayerXLogEntry> logs;
  final ValueChanged<LayerXLogEntry> onInspect;

  const LxEverythingPane({
    super.key,
    required this.logs,
    required this.onInspect,
  });

  @override
  State<LxEverythingPane> createState() => _LxEverythingPaneState();
}

class _LxEverythingPaneState extends State<LxEverythingPane> {
  _EverythingTab _tab = _EverythingTab.console;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _subSwitch(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (_tab) {
      case _EverythingTab.console:
        return LxConsolePane(logs: widget.logs, onInspect: widget.onInspect);
      case _EverythingTab.network:
        return LxNetworkPane(logs: widget.logs, onInspect: widget.onInspect);
      case _EverythingTab.dashboard:
        return LxDashboardPane(logs: widget.logs, onInspect: widget.onInspect);
    }
  }

  Widget _subSwitch() {
    Widget chip(String label, _EverythingTab tab) {
      final active = _tab == tab;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: LxKit.tapTarget(
          label: label,
          selected: active,
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? LxTheme.surfaceHigh : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? LxTheme.borderActive : Colors.transparent),
            ),
            child: Text(
              label,
              style: LxTheme.caption.copyWith(
                color: active ? LxTheme.textPrimary : LxTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      // ≥48dp tall so each chip's accessible hit area fits without clipping;
      // the visible chip keeps its own small size, centered within.
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Console', _EverythingTab.console),
          chip('Network', _EverythingTab.network),
          chip('Dashboard', _EverythingTab.dashboard),
        ],
      ),
    );
  }
}
