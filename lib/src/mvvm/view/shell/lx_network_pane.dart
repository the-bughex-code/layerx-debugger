// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';

enum _NetFilter { all, errors, slow, changed }

/// The "Network" destination — request rows à la Postman / Charles.
class LxNetworkPane extends StatefulWidget {
  final List<LayerXLogEntry> logs;
  final ValueChanged<LayerXLogEntry> onInspect;

  const LxNetworkPane({
    super.key,
    required this.logs,
    required this.onInspect,
  });

  @override
  State<LxNetworkPane> createState() => _LxNetworkPaneState();
}

class _LxNetworkPaneState extends State<LxNetworkPane> {
  _NetFilter _filter = _NetFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var rows = widget.logs.where(LxKit.isNetwork).toList();

    rows = rows.where((e) {
      switch (_filter) {
        case _NetFilter.all:
          break;
        case _NetFilter.errors:
          if ((e.statusCode ?? 0) < 400) return false;
          break;
        case _NetFilter.slow:
          if ((LxKit.durationOf(e) ?? 0) < 800) return false;
          break;
        case _NetFilter.changed:
          if (!e.responseChanged) return false;
          break;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!(e.endpoint ?? '').toLowerCase().contains(q) &&
            !(e.methodName ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        _searchField(),
        _filterChips(),
        Expanded(
          child: rows.isEmpty
              ? LxKit.emptyState(Icons.wifi_tethering_off, 'NO REQUESTS',
                  'No network calls match this view yet.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _requestRow(rows[i]),
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
                  hintText: 'filter endpoints…',
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

  Widget _filterChips() {
    Widget chip(String label, _NetFilter f) {
      final active = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = f),
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
              style: LxTheme.monoSm.copyWith(
                color: active ? LxTheme.textPrimary : LxTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          chip('All', _NetFilter.all),
          chip('Errors', _NetFilter.errors),
          chip('Slow', _NetFilter.slow),
          chip('Δ Changed', _NetFilter.changed),
        ],
      ),
    );
  }

  Widget _requestRow(LayerXLogEntry e) {
    final method = (e.methodName ?? 'GET').toUpperCase();
    final mColor = LxKit.methodColor(method);
    final sColor = LxKit.statusColor(e.statusCode);
    final dur = LxKit.durationOf(e);
    final durLabel = dur == null
        ? ''
        : dur >= 1000
            ? '${(dur / 1000).toStringAsFixed(1)}s'
            : '${dur}ms';
    final isError = (e.statusCode ?? 0) >= 400;
    final rail = e.responseChanged
        ? LxTheme.accentOrange
        : isError
            ? sColor
            : null;

    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          LxKit.pill(method, mColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LxKit.shortPath(e.endpoint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LxTheme.mono.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${e.statusCode ?? '—'}${e.responseChanged ? 'Δ' : ''}',
            style: TextStyle(
                color: e.responseChanged ? LxTheme.accentOrange : sColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace'),
          ),
          if (durLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(durLabel, style: LxTheme.monoSm),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onInspect(e),
        child: Container(
          decoration: rail != null
              ? LxKit.railCard(rail)
              : BoxDecoration(
                  color: LxTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LxTheme.border),
                ),
          child: inner,
        ),
      ),
    );
  }
}
