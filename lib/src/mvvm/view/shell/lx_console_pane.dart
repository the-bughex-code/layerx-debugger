// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
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
  LayerXLogCategory? _category;
  LayerXLogLevel? _level;
  String _query = '';
  final TextEditingController _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _queryCtrl.clear();
      _query = '';
      _category = null;
      _level = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.logs.length;
    var rows = widget.logs.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_level != null && e.level != _level) return false;
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
        _categoryChips(),
        // Partial results never masquerade as everything: a slim honest
        // header with a one-tap way back.
        if (rows.isNotEmpty && rows.length < total)
          LxKit.filterSummaryBar(rows.length, total, _clearFilters),
        Expanded(
          child: rows.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => LxKit.stagger(i, _logRow(rows[i])),
                )
              // Filtered-empty ≠ truly-empty: when filters hid every row,
              // say so and offer recovery instead of pretending silence.
              : total > 0
                  ? LxKit.emptyState(
                      Icons.filter_alt_off,
                      'NOTHING MATCHES',
                      'Showing 0 of $total — clear the filters to see '
                          'everything.',
                      action: LxKit.clearFiltersButton(_clearFilters),
                    )
                  : LxKit.emptyState(Icons.terminal, 'NO LOGS',
                      'Nothing has been logged yet. ${LxKit.scopeHonestyLine}'),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
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
                      controller: _queryCtrl,
                      style: LxTheme.mono.copyWith(fontSize: 12),
                      cursorColor: LxTheme.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: 'search logs…',
                        hintStyle: LxTheme.caption,
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _levelMenu(),
        ],
      ),
    );
  }

  Widget _levelMenu() {
    return Container(
      // ≥48dp a11y floor: a plain 48×48 box tightly sizes the inner
      // PopupMenuButton's IconButton to a real 48×48 tap target (the glyph
      // stays 18dp). The border lives in foregroundDecoration so it paints
      // OVER the child rather than insetting it to 46 — the search field keeps
      // its 38dp height and stays vertically centered as the row grows to 48.
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: _level == null ? LxTheme.border : LxTheme.accent),
      ),
      child: PopupMenuButton<LayerXLogLevel?>(
        tooltip: 'Filter by level',
        icon: Icon(Icons.filter_list,
            size: 18,
            color: _level == null ? LxTheme.textSecondary : LxTheme.accent),
        color: LxTheme.surfaceHigh,
        onSelected: (v) => setState(() => _level = v),
        itemBuilder: (_) => [
          const PopupMenuItem<LayerXLogLevel?>(
              value: null, child: Text('All levels')),
          for (final l in LayerXLogLevel.values)
            PopupMenuItem<LayerXLogLevel?>(
              value: l,
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: l.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(l.label),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    final present = <LayerXLogCategory>{
      for (final e in widget.logs) e.category
    };
    final ordered = LayerXLogCategory.values.where(present.contains).toList();

    Widget chip(String label, LayerXLogCategory? c, Color color) {
      final active = _category == c;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: LxKit.tapTarget(
          label: label,
          selected: active,
          onTap: () => setState(() => _category = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  active ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.45)
                      : Colors.transparent),
            ),
            child: Text(label,
                style: LxTheme.caption
                    .copyWith(color: active ? color : LxTheme.textSecondary)),
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
          chip('All', null, LxTheme.textPrimary),
          for (final c in ordered) chip(c.label, c, c.color),
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
                      color: e.level == LayerXLogLevel.error ||
                              e.level == LayerXLogLevel.fatal
                          ? LxTheme.accentRed
                          : LxTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(meta, style: LxTheme.caption),
                ],
              ),
            ),
            // ≥48dp tap target around the 14dp glyph, labeled for readers.
            LxKit.tapTarget(
              label: 'Copy this log',
              onTap: () => LxCopy.copy(context, LxKit.copySummary(e)),
              child: const Icon(Icons.copy, size: 14, color: LxTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
