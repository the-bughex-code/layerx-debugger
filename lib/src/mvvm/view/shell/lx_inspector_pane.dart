// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_schema_change.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';
import 'package:layerx_debugger/src/repository/layerx_report_formatter.dart';

/// The "Inspector" destination — the selected entry rendered top-to-bottom as
/// an assignable bug report: who to assign & why → suggested fix → details →
/// what the app sent (request) → what the server answered (response) →
/// journey → collapsed technical details.
class LxInspectorPane extends StatefulWidget {
  final LayerXLogEntry? log;
  const LxInspectorPane({super.key, required this.log});

  @override
  State<LxInspectorPane> createState() => _LxInspectorPaneState();
}

class _LxInspectorPaneState extends State<LxInspectorPane> {
  bool _stackOpen = false;

  @override
  void didUpdateWidget(covariant LxInspectorPane old) {
    super.didUpdateWidget(old);
    if (old.log?.id != widget.log?.id) {
      _stackOpen = false;
    }
  }

  /// Resilient wrapper around [LayerXBlameEngine.analyze]: the report builder
  /// must never throw, so any exception is swallowed and treated as "no
  /// verdict" rather than crashing the detail screen.
  static LayerXBlameInfo? _blameOf(LayerXLogEntry e) {
    try {
      return LayerXBlameEngine.analyze(e);
    } catch (_) {
      return null;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(e),
        Expanded(child: _report(e)),
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

  /// The whole bug report as ONE scroll, in the order a reader needs it:
  /// verdict → suggestion → details → request → response (+ changed-shape
  /// diff) → journey → collapsed stack. Empty sections are omitted entirely.
  Widget _report(LayerXLogEntry e) {
    final blame = _blameOf(e);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (blame != null) ...[
          LxKit.sectionLabel('WHO TO ASSIGN & WHY'),
          _blameCard(blame),
          const SizedBox(height: 14),
        ],
        if (e.suggestedSolution != null) ...[
          LxKit.sectionLabel('WHAT WE SUGGEST'),
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
        LxKit.sectionLabel('DETAILS'),
        _kv('Message', e.message),
        _kv('Source', e.source.label),
        _kv('Category', e.category.label),
        _kv('Level', e.level.label),
        if (e.sourceFile != null)
          _kv('Location', '${e.sourceFile}:${e.sourceLine ?? '?'}'),
        if (e.statusCode != null) _kv('Status', '${e.statusCode}'),
        if (e.errorCode != null) _kv('Error code', e.errorCode!),
        if (e.controllerName != null) _kv('Controller', e.controllerName!),
        if (e.screenName != null) _kv('Screen', e.screenName!),
        if (LxKit.durationOf(e) != null) _kv('Duration', '${LxKit.durationOf(e)}ms'),
        _kv(
            'Time',
            '${LayerXReportFormatter.relativeTime(e.timestamp)} · '
                '${LxKit.clockTime(e.timestamp)}'),
        if (e.occurrenceCount > 1) _kv('Occurrences', '×${e.occurrenceCount}'),
        const SizedBox(height: 14),
        ..._payloadSection('WHAT THE APP SENT (REQUEST)', e.requestPayload),
        ..._payloadSection(
            'WHAT THE SERVER ANSWERED (RESPONSE)', e.responsePayload),
        if (e.responseChanged && e.schemaChanges.isNotEmpty) ...[
          LxKit.sectionLabel('RESPONSE CHANGED SHAPE'),
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
        if (e.journey.isNotEmpty) ...[
          LxKit.sectionLabel('JOURNEY'),
          _trace(e),
          const SizedBox(height: 14),
        ],
        if (e.stackTrace != null) _stackSection(context, e.stackTrace!),
      ],
    );
  }

  Widget _blameCard(LayerXBlameInfo blame) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blame.color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(blame.icon, color: blame.color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  blame.responsibleParty,
                  style: LxTheme.bodyPrimary.copyWith(
                      fontWeight: FontWeight.w700, color: blame.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(blame.explanation,
              style: LxTheme.bodySecondary.copyWith(height: 1.5)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LxTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LxTheme.border),
            ),
            child: Text(blame.qaNote,
                style: LxTheme.bodySecondary.copyWith(height: 1.5)),
          ),
        ],
      ),
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
            child: Text(k, style: LxTheme.caption),
          ),
          Expanded(
            child: Text(v,
                style: LxTheme.bodySecondary.copyWith(color: LxTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  /// A payload section (request or response). Empty payloads are omitted
  /// entirely — no empty-state placeholder.
  List<Widget> _payloadSection(String label, String? body) {
    if (body == null || body.trim().isEmpty) return const [];
    return [
      Row(
        children: [
          Expanded(child: LxKit.sectionLabel(label)),
          TextButton.icon(
            onPressed: () => LxCopy.copy(context, body),
            icon: const Icon(Icons.copy, size: 14, color: LxTheme.textSecondary),
            label: Text('Copy', style: LxTheme.bodySecondary),
          ),
        ],
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
      const SizedBox(height: 14),
    ];
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
                  Text('TECHNICAL DETAILS', style: LxTheme.sectionLabel),
                  const Spacer(),
                  if (_stackOpen)
                    GestureDetector(
                      onTap: () => LxCopy.copy(context, stack),
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

  /// The journey timeline, rendered inline (journeys are short).
  Widget _trace(LayerXLogEntry e) {
    return Column(
      children: [
        for (var i = 0; i < e.journey.length; i++) _traceStep(e, i),
      ],
    );
  }

  Widget _traceStep(LayerXLogEntry e, int i) {
    final step = e.journey[i];
    final last = i == e.journey.length - 1;
    final color = step.type == 'error' ? LxTheme.accentRed : LxTheme.accent;
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
                      style: LxTheme.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
