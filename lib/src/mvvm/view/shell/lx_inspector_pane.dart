// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_schema_change.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';

/// The "Inspector" destination — a deep dive on the selected log entry.
class LxInspectorPane extends StatefulWidget {
  final LayerXLogEntry? log;
  const LxInspectorPane({super.key, required this.log});

  @override
  State<LxInspectorPane> createState() => _LxInspectorPaneState();
}

class _LxInspectorPaneState extends State<LxInspectorPane> {
  int _tab = 0;
  bool _stackOpen = false;

  @override
  void didUpdateWidget(covariant LxInspectorPane old) {
    super.didUpdateWidget(old);
    if (old.log?.id != widget.log?.id) {
      _tab = 0;
      _stackOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.log;
    if (e == null) {
      return LxKit.emptyState(
        Icons.travel_explore,
        'NOTHING SELECTED',
        'Tap any request, log or issue to inspect it here.',
      );
    }

    final tabs = <String>['Overview', 'Response', 'Request', 'Trace'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(e),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) _tabButton(tabs[i], i),
            ],
          ),
        ),
        Expanded(child: _tabBody(e)),
      ],
    );
  }

  Widget _header(LayerXLogEntry e) {
    final isNet = LxKit.isNetwork(e);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LxTheme.border)),
      ),
      child: Row(
        children: [
          if (isNet) ...[
            LxKit.pill((e.methodName ?? 'GET').toUpperCase(),
                LxKit.methodColor(e.methodName)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(LxKit.shortPath(e.endpoint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LxTheme.mono.copyWith(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text('${e.statusCode ?? '—'}',
                style: TextStyle(
                    color: LxKit.statusColor(e.statusCode),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ] else ...[
            Icon(LxKit.levelIcon(e.level), color: e.level.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(e.message.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LxTheme.bodyPrimary.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? LxTheme.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: active ? LxTheme.borderActive : Colors.transparent),
        ),
        child: Text(label,
            style: LxTheme.monoSm.copyWith(
                color: active ? LxTheme.textPrimary : LxTheme.textSecondary)),
      ),
    );
  }

  Widget _tabBody(LayerXLogEntry e) {
    switch (_tab) {
      case 1:
        return _payload('Response', e.responsePayload);
      case 2:
        return _payload('Request', e.requestPayload);
      case 3:
        return _trace(e);
      default:
        return _overview(e);
    }
  }

  Widget _overview(LayerXLogEntry e) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (e.suggestedSolution != null) ...[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: LxTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LxTheme.accentAmber.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: LxTheme.accentAmber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.suggestedSolution!,
                      style: LxTheme.bodySecondary.copyWith(height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (e.responseChanged && e.schemaChanges.isNotEmpty) ...[
          LxKit.sectionLabel('CONTRACT CHANGES'),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: LxTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LxTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: e.schemaChanges.map(_schemaRow).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],
        LxKit.sectionLabel('DETAILS'),
        _kv('Message', e.message),
        _kv('Source', e.source.name),
        _kv('Category', e.category.label),
        _kv('Level', e.level.label),
        if (e.sourceFile != null)
          _kv('Location', '${e.sourceFile}:${e.sourceLine ?? '?'}'),
        if (e.statusCode != null) _kv('Status', '${e.statusCode}'),
        if (e.errorCode != null) _kv('Error code', e.errorCode!),
        if (e.controllerName != null) _kv('Controller', e.controllerName!),
        if (e.screenName != null) _kv('Screen', e.screenName!),
        if (LxKit.durationOf(e) != null) _kv('Duration', '${LxKit.durationOf(e)}ms'),
        _kv('Time', e.timestamp.toIso8601String()),
        if (e.occurrenceCount > 1) _kv('Occurrences', '×${e.occurrenceCount}'),
        if (e.stackTrace != null) ...[
          const SizedBox(height: 14),
          _stackSection(context, e.stackTrace!),
        ],
      ],
    );
  }

  Widget _schemaRow(LayerXSchemaChange c) {
    Color color;
    String prefix;
    switch (c.diffType) {
      case LayerXSchemaDiffType.added:
        color = LxTheme.accentGreen;
        prefix = '+';
        break;
      case LayerXSchemaDiffType.removed:
        color = LxTheme.accentRed;
        prefix = '−';
        break;
      default:
        color = LxTheme.accentAmber;
        prefix = '~';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$prefix ${c.key}  (${c.label.toLowerCase()})',
        style: LxTheme.mono.copyWith(color: color, fontSize: 11.5),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: LxTheme.monoSm),
          ),
          Expanded(
            child: Text(v,
                style: LxTheme.bodySecondary.copyWith(color: LxTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _stackSection(BuildContext context, String stack) {
    return Container(
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LxTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _stackOpen = !_stackOpen),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(_stackOpen ? Icons.expand_more : Icons.chevron_right,
                      size: 18, color: LxTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text('STACK TRACE', style: LxTheme.sectionLabel),
                  const Spacer(),
                  if (_stackOpen)
                    GestureDetector(
                      onTap: () => _copy(context, stack, 'Stack trace copied ✓'),
                      child: const Icon(Icons.copy,
                          size: 14, color: LxTheme.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          if (_stackOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: SelectableText(stack,
                  style: LxTheme.mono.copyWith(fontSize: 11, height: 1.5)),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(LxTheme.snackBar(toast));
  }

  Widget _payload(String label, String? body) {
    if (body == null || body.trim().isEmpty) {
      return LxKit.emptyState(
          Icons.data_object, 'NO $label BODY', 'This entry has no $label payload.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: body)),
            icon: const Icon(Icons.copy, size: 14, color: LxTheme.textSecondary),
            label: Text('Copy', style: LxTheme.monoSm),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: LxTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LxTheme.border),
          ),
          child: SelectableText(body, style: LxTheme.mono.copyWith(fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _trace(LayerXLogEntry e) {
    if (e.journey.isEmpty) {
      return LxKit.emptyState(
          Icons.route, 'NO TRACE', 'No journey steps were captured for this entry.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: e.journey.length,
      itemBuilder: (_, i) {
        final step = e.journey[i];
        final last = i == e.journey.length - 1;
        final color =
            step.type == 'error' ? LxTheme.accentRed : LxTheme.accent;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(width: 1.5, color: LxTheme.border),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title,
                          style: LxTheme.bodyPrimary.copyWith(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      if (step.description != null) ...[
                        const SizedBox(height: 2),
                        Text(step.description!, style: LxTheme.bodySecondary),
                      ],
                      const SizedBox(height: 2),
                      Text(LxKit.clockTime(step.timestamp),
                          style: LxTheme.monoSm.copyWith(color: LxTheme.textDim)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
