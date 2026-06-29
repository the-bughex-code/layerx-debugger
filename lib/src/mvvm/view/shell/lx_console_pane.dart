// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';

/// The "Console" destination — a chronological timeline of every log source.
class LxConsolePane extends StatefulWidget {
  final List<LayerXLogEntry> logs;
  final ValueChanged<LayerXLogEntry> onInspect;

  const LxConsolePane({
    super.key,
    required this.logs,
    required this.onInspect,
  });

  @override
  State<LxConsolePane> createState() => _LxConsolePaneState();
}

class _LxConsolePaneState extends State<LxConsolePane> {
  LayerXLogSource? _source;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var rows = widget.logs.where((e) {
      if (_source != null && e.source != _source) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!e.message.toLowerCase().contains(q) &&
            !(e.endpoint ?? '').toLowerCase().contains(q) &&
            !(e.controllerName ?? '').toLowerCase().contains(q) &&
            !(e.screenName ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        _searchField(),
        _sourceChips(),
        Expanded(
          child: rows.isEmpty
              ? LxKit.emptyState(Icons.terminal, 'NO LOGS',
                  'Nothing matches the current filter.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => LxKit.stagger(i, _logRow(rows[i])),
                ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LxTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LxTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: LxTheme.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: LxTheme.mono.copyWith(fontSize: 12),
                cursorColor: LxTheme.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'search logs…',
                  hintStyle: LxTheme.monoSm.copyWith(color: LxTheme.textDim),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceChips() {
    Widget chip(String label, LayerXLogSource? s, Color color) {
      final active = _source == s;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _source = s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? color.withValues(alpha: 0.45) : Colors.transparent),
            ),
            child: Text(
              label,
              style: LxTheme.monoSm.copyWith(
                color: active ? color : LxTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null, LxTheme.textPrimary),
          chip('Network', LayerXLogSource.network, LayerXLogSource.network.color),
          chip('App', LayerXLogSource.app, LayerXLogSource.app.color),
          chip('Backend', LayerXLogSource.backend, LayerXLogSource.backend.color),
          chip('Server', LayerXLogSource.server, LayerXLogSource.server.color),
        ],
      ),
    );
  }

  Widget _logRow(LayerXLogEntry e) {
    final rail = e.level.color;
    final meta = [
      LxKit.clockTime(e.timestamp),
      e.source.name,
      if (e.occurrenceCount > 1) '×${e.occurrenceCount}',
    ].join(' · ');

    return InkWell(
      onTap: () => widget.onInspect(e),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LxTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.only(right: 11, top: 1),
              decoration: BoxDecoration(
                color: rail,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(LxKit.levelIcon(e.level), color: rail, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.message.split('\n').first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LxTheme.bodyPrimary.copyWith(
                      fontSize: 12.5,
                      color: e.level.color == LxTheme.accentRed
                          ? LxTheme.accentRed
                          : LxTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(meta, style: LxTheme.monoSm.copyWith(color: LxTheme.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
