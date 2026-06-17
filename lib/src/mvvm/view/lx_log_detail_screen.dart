// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_schema_change.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_detail_card.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_journey_timeline.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_solution_card.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_source_chip.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

class LxLogDetailScreen extends StatefulWidget {
  final LayerXLogEntry log;

  const LxLogDetailScreen({super.key, required this.log});

  @override
  State<LxLogDetailScreen> createState() => _LxLogDetailScreenState();
}

class _LxLogDetailScreenState extends State<LxLogDetailScreen> {
  bool _showStackTrace = false;
  bool _showFullRequest = false;
  bool _showFullResponse = false;
  bool _showFullPrevResponse = false;
  bool _showSchemaDiff = true;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final formattedTime =
        DateFormat('dd MMM yyyy · HH:mm:ss.SSS').format(log.timestamp);
    final totalOccurrences = log.occurrenceCount;

    return Scaffold(
      backgroundColor: LxTheme.bg,
      appBar: AppBar(
        title: Text(
          'LOG DETAIL',
          style: LxTheme.sectionLabel.copyWith(
            fontSize: 13,
            color: LxTheme.textPrimary,
            letterSpacing: 2,
          ),
        ),
        elevation: 0,
        backgroundColor: LxTheme.surface,
        iconTheme: const IconThemeData(color: LxTheme.textSecondary),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            tooltip: 'Copy full log',
            onPressed: () => _copyFullLog(context, log),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: LxTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32, top: 8),
        children: [
          _buildHeader(log, totalOccurrences),
          _buildBlameCard(log),
          if (log.screenName != null ||
              log.controllerName != null ||
              log.serviceName != null ||
              log.repoName != null ||
              log.methodName != null)
            LxDetailCard(
              title: 'Where It Happened',
              accentColor: LxTheme.accentBlue,
              child: Column(
                children: [
                  _row(context, '📱', 'Screen', log.screenName),
                  _row(context, '🎮', 'Controller', log.controllerName),
                  _row(context, '⚙️', 'Service', log.serviceName),
                  _row(context, '🗄️', 'Repository', log.repoName),
                  _row(
                    context,
                    '🔧',
                    'Method',
                    log.methodName != null ? '${log.methodName}()' : null,
                    copyVal: log.methodName,
                  ),
                ],
              ),
            ),
          if (log.source == LayerXLogSource.server ||
              log.source == LayerXLogSource.backend ||
              log.source == LayerXLogSource.network ||
              log.endpoint != null)
            LxDetailCard(
              title: 'API Details',
              accentColor: LxTheme.accentCyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.endpoint != null)
                    _row(context, '🔗', 'Endpoint', log.endpoint),
                  if (log.statusCode != null)
                    _row(
                        context, '🚦', 'Status', _statusLabel(log.statusCode!)),
                  if (log.errorCode != null)
                    _row(context, '⚠️', 'Error Code', log.errorCode),
                  if (log.requestPayload != null) ...[
                    const SizedBox(height: 12),
                    _sectionDivider('Request Payload'),
                    const SizedBox(height: 6),
                    _jsonWidget(log.requestPayload!, _showFullRequest,
                        onToggle: () {
                      setState(() => _showFullRequest = !_showFullRequest);
                    }),
                  ],
                  if (log.responseChanged) ...[
                    const SizedBox(height: 16),
                    _buildResponseChangedBanner(log),
                  ],
                  if (log.responseChanged && log.schemaChanges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSchemaDiffTable(log),
                  ],
                  if (log.responseChanged &&
                      log.previousResponsePayload != null) ...[
                    const SizedBox(height: 12),
                    _sectionDivider('Previous Response (Before Change)'),
                    const SizedBox(height: 6),
                    _jsonWidget(
                        log.previousResponsePayload!, _showFullPrevResponse,
                        onToggle: () {
                      setState(
                          () => _showFullPrevResponse = !_showFullPrevResponse);
                    }),
                    const SizedBox(height: 12),
                    _sectionDivider('Current Response (After Change)'),
                    const SizedBox(height: 6),
                    _jsonWidget(log.responsePayload!, _showFullResponse,
                        onToggle: () {
                      setState(() => _showFullResponse = !_showFullResponse);
                    }),
                  ] else if (log.responsePayload != null) ...[
                    const SizedBox(height: 12),
                    _sectionDivider('Response Payload'),
                    const SizedBox(height: 6),
                    _jsonWidget(log.responsePayload!, _showFullResponse,
                        onToggle: () {
                      setState(() => _showFullResponse = !_showFullResponse);
                    }),
                  ],
                ],
              ),
            ),
          LxJourneyTimeline(journey: log.journey),
          if (log.suggestedSolution != null)
            LxSolutionCard(
              solution: log.suggestedSolution!,
              sourceLabel: log.source.label,
            ),
          if (log.stackTrace != null) _buildStackTraceCard(log),
          if (totalOccurrences > 1)
            LxDetailCard(
              title: 'Occurrences (×$totalOccurrences)',
              accentColor: LxTheme.accentAmber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(log.repeatTimestamps.length, (idx) {
                  final time = log.repeatTimestamps[idx];
                  final formatted =
                      DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time);
                  final label = idx == 0 ? 'first' : 'repeated';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.repeat, size: 14, color: LxTheme.accentAmber),
                        const SizedBox(width: 8),
                        Text(
                          formatted,
                          style: LxTheme.mono.copyWith(fontSize: 12),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: LxTheme.pill(
                            idx == 0 ? LxTheme.textSecondary : LxTheme.accentAmber,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: idx == 0
                                  ? LxTheme.textSecondary
                                  : LxTheme.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          LxDetailCard(
            title: 'Metadata & Device Environment',
            child: Column(
              children: [
                _row(context, '🔑', 'Log ID', log.id),
                _row(context, '📦', 'Environment',
                    LayerXDebugger.config.environment.name),
                _row(context, '⏰', 'Timestamp', formattedTime),
                _row(
                  context,
                  '📱',
                  'Platform OS',
                  Theme.of(context).platform.toString().split('.').last,
                ),
                _row(
                  context,
                  '🖥️',
                  'Resolution',
                  '${MediaQuery.of(context).size.width.toInt()} × '
                      '${MediaQuery.of(context).size.height.toInt()} '
                      '(×${MediaQuery.of(context).devicePixelRatio.toStringAsFixed(1)})',
                ),
                _row(
                  context,
                  '🔄',
                  'Orientation',
                  MediaQuery.of(context).orientation.toString().split('.').last,
                ),
                _row(
                  context,
                  '🌐',
                  'App Locale',
                  Localizations.localeOf(context).toString(),
                ),
                if (log.extras.isNotEmpty)
                  ...log.extras.entries.map(
                    (e) => _row(context, '📌', e.key, e.value.toString()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LayerXLogEntry log, int totalOccurrences) {
    final severityColor = log.level.color;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: LxTheme.card(glowColor: severityColor),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.level.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.statusCode != null
                            ? '${log.statusCode} ${log.message.split('\n').first}'
                            : log.message.split('\n').first,
                        style: LxTheme.mono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: severityColor,
                        ),
                      ),
                      if (log.message.contains('\n')) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.message.substring(log.message.indexOf('\n') + 1),
                          style: LxTheme.bodySecondary.copyWith(
                            color: LxTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LxTheme.divider,
            const SizedBox(height: 12),
            Row(
              children: [
                LxSourceChip(source: log.source),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: LxTheme.pill(severityColor),
                  child: Text(
                    log.level.label,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (log.responseChanged) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: LxTheme.pill(LxTheme.accentOrange),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz, size: 10, color: LxTheme.accentOrange),
                        const SizedBox(width: 4),
                        Text(
                          'API CHANGED',
                          style: LxTheme.sectionLabel.copyWith(
                            color: LxTheme.accentOrange,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (totalOccurrences > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: LxTheme.pill(LxTheme.accentAmber),
                    child: Text(
                      '×$totalOccurrences occurrences',
                      style: LxTheme.sectionLabel.copyWith(
                        color: LxTheme.accentAmber,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlameCard(LayerXLogEntry log) {
    final blameInfo = LayerXBlameEngine.analyze(log);
    if (blameInfo == null) return const SizedBox.shrink();

    final c = blameInfo.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        boxShadow: LxTheme.glowShadow(c, spread: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(blameInfo.icon, color: c, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WHO OWNS THIS BUG?',
                    style: LxTheme.sectionLabel.copyWith(
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              blameInfo.responsibleParty,
              style: LxTheme.mono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LxTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LxTheme.border),
              ),
              child: Text(
                blameInfo.explanation,
                style: LxTheme.bodySecondary.copyWith(
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 14, color: c),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blameInfo.qaNote,
                    style: LxTheme.bodySecondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseChangedBanner(LayerXLogEntry log) {
    final changeCount = log.schemaChanges.length;
    final addedCount = log.schemaChanges
        .where((c) => c.diffType == LayerXSchemaDiffType.added)
        .length;
    final removedCount = log.schemaChanges
        .where((c) => c.diffType == LayerXSchemaDiffType.removed)
        .length;
    final typeChangedCount = log.schemaChanges
        .where((c) => c.diffType == LayerXSchemaDiffType.typeChanged)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LxTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LxTheme.accentOrange.withValues(alpha: 0.45), width: 1.5),
        boxShadow: LxTheme.glowShadow(LxTheme.accentOrange, spread: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: LxTheme.accentOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ API RESPONSE CHANGED',
                  style: LxTheme.sectionLabel.copyWith(
                    color: LxTheme.accentOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The response payload for "${log.endpoint ?? 'this endpoint'}" '
            'has changed since the previous call.',
            style: LxTheme.bodySecondary.copyWith(
              height: 1.4,
            ),
          ),
          if (changeCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (addedCount > 0)
                  _diffBadge('+$addedCount added', LxTheme.accentGreen),
                if (removedCount > 0)
                  _diffBadge('-$removedCount removed', LxTheme.accentRed),
                if (typeChangedCount > 0)
                  _diffBadge('$typeChangedCount type changed', LxTheme.accentPurple),
                if (changeCount - addedCount - removedCount - typeChangedCount >
                    0)
                  _diffBadge(
                    '${changeCount - addedCount - removedCount - typeChangedCount} values changed',
                    LxTheme.accentOrange,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchemaDiffTable(LayerXLogEntry log) {
    const diffColors = {
      LayerXSchemaDiffType.added: LxTheme.accentGreen,
      LayerXSchemaDiffType.removed: LxTheme.accentRed,
      LayerXSchemaDiffType.typeChanged: LxTheme.accentPurple,
      LayerXSchemaDiffType.valueChanged: LxTheme.accentOrange,
    };
    const diffIcons = {
      LayerXSchemaDiffType.added: '+',
      LayerXSchemaDiffType.removed: '−',
      LayerXSchemaDiffType.typeChanged: '~',
      LayerXSchemaDiffType.valueChanged: '≠',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: LxTheme.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(color: LxTheme.border),
              left: BorderSide(color: LxTheme.border),
              right: BorderSide(color: LxTheme.border),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_outlined,
                  size: 14, color: LxTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "SCHEMA DIFF — ${log.schemaChanges.length} field${log.schemaChanges.length > 1 ? 's' : ''} changed",
                  style: LxTheme.sectionLabel.copyWith(
                    fontSize: 10,
                    color: LxTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showSchemaDiff = !_showSchemaDiff),
                child: Text(
                  _showSchemaDiff ? 'Hide' : 'Show',
                  style: LxTheme.labelBold.copyWith(
                    fontSize: 11,
                    color: LxTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSchemaDiff)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: LxTheme.border),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              children: log.schemaChanges.asMap().entries.map((entry) {
                final idx = entry.key;
                final change = entry.value;
                final color = diffColors[change.diffType]!;
                final icon = diffIcons[change.diffType]!;
                final isLast = idx == log.schemaChanges.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    color: LxTheme.surface,
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: LxTheme.border),
                          ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          icon,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    change.key,
                                    style: LxTheme.mono.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: LxTheme.pill(color),
                                  child: Text(
                                    change.label,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (change.previousValue != null) ...[
                              const SizedBox(height: 4),
                              _valueRow('Before', change.previousValue!,
                                  LxTheme.accentRed),
                            ],
                            if (change.currentValue != null) ...[
                              const SizedBox(height: 3),
                              _valueRow(
                                  'After',
                                  change.currentValue!,
                                  LxTheme.accentGreen),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _valueRow(String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: LxTheme.monoSm.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: textColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              value,
              style: LxTheme.mono.copyWith(
                fontSize: 10,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackTraceCard(LayerXLogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: LxTheme.card(),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: _showStackTrace,
          title: Text(
            'STACK TRACE',
            style: LxTheme.sectionLabel.copyWith(color: LxTheme.textPrimary),
          ),
          leading: const Icon(Icons.code, color: LxTheme.accentBlue),
          trailing: TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.stackTrace!));
              ScaffoldMessenger.of(context).showSnackBar(
                LxTheme.snackBar('Stack trace copied to clipboard ✓'),
              );
            },
            icon: const Icon(Icons.copy, size: 12, color: LxTheme.accentBlue),
            label: Text(
              'Copy',
              style: LxTheme.mono.copyWith(fontSize: 11, color: LxTheme.accentBlue),
            ),
          ),
          onExpansionChanged: (val) => setState(() => _showStackTrace = val),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LxTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LxTheme.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildStackTraceText(log.stackTrace!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String icon,
    String label,
    String? value, {
    String? copyVal,
  }) {
    if (value == null) return const SizedBox.shrink();
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: copyVal ?? value));
        ScaffoldMessenger.of(context).showSnackBar(
          LxTheme.snackBar('Copied "$label" to clipboard ✓'),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: LxTheme.monoSm.copyWith(
                  color: LxTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: LxTheme.mono.copyWith(
                  fontSize: 12,
                  color: LxTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: LxTheme.sectionLabel.copyWith(color: LxTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: LxTheme.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jsonWidget(
    String rawJson,
    bool showFull, {
    required VoidCallback onToggle,
  }) {
    String formatted;
    try {
      final parsed = json.decode(rawJson);
      formatted = const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      formatted = rawJson;
    }

    final isTruncated = !showFull && formatted.length > 300;
    final display = isTruncated ? '${formatted.substring(0, 300)}…' : formatted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LxTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LxTheme.border),
          ),
          child: RichText(text: TextSpan(children: _highlightJson(display))),
        ),
        if (formatted.length > 300)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggle,
              child: Text(
                showFull ? 'Show Less ↑' : 'Show More ↓',
                style: LxTheme.mono.copyWith(fontSize: 11, color: LxTheme.accentBlue),
              ),
            ),
          ),
      ],
    );
  }

  Widget _diffBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: LxTheme.pill(color),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<TextSpan> _highlightJson(String rawJson) {
    final spans = <TextSpan>[];
    // Custom syntax highlighters for terminal style
    // Keys (e.g. "key":) -> accentBlue
    // Strings -> accentGreen
    // Booleans/nulls -> accentRed (or accentPurple)
    // Numbers -> accentOrange
    // Syntax punctuation -> textSecondary
    final regex = RegExp(
      r'("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?)'
      r'|\b(true|false|null)\b'
      r'|-?\d+(\.\d+)?([eE][+-]?\d+)?'
      r'|[{}\[\]:,]'
      r'|\s+',
    );

    final matches = regex.allMatches(rawJson);
    var lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: rawJson.substring(lastMatchEnd, match.start),
          style: LxTheme.mono.copyWith(color: LxTheme.textPrimary, fontSize: 11),
        ));
      }

      final token = match.group(0)!;
      var style = LxTheme.mono.copyWith(color: LxTheme.textPrimary, fontSize: 11);

      if (token.startsWith('"')) {
        style = token.endsWith(':')
            ? LxTheme.mono.copyWith(
                color: LxTheme.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              )
            : LxTheme.mono.copyWith(
                color: LxTheme.accentGreen,
                fontSize: 11,
              );
      } else if (token == 'true' || token == 'false') {
        style = LxTheme.mono.copyWith(
          color: LxTheme.accentPurple,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        );
      } else if (token == 'null') {
        style = LxTheme.mono.copyWith(
          color: LxTheme.accentRed,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        );
      } else if (RegExp(r'^-?\d+').hasMatch(token)) {
        style = LxTheme.mono.copyWith(
          color: LxTheme.accentOrange,
          fontSize: 11,
        );
      } else if (RegExp(r'[{}\[\]:,]').hasMatch(token)) {
        style = LxTheme.mono.copyWith(
          color: LxTheme.textSecondary,
          fontSize: 11,
        );
      }

      spans.add(TextSpan(text: token, style: style));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < rawJson.length) {
      spans.add(TextSpan(
        text: rawJson.substring(lastMatchEnd),
        style: LxTheme.mono.copyWith(color: LxTheme.textPrimary, fontSize: 11),
      ));
    }

    return spans;
  }

  Widget _buildStackTraceText(String stackTrace) {
    final lines = stackTrace.split('\n');
    final spans = <TextSpan>[];
    final pkg = LayerXDebugger.config.packageName;

    for (final line in lines) {
      final isProjectLine = pkg != null
          ? line.contains('package:$pkg')
          : line.contains('package:') &&
              !line.contains('package:flutter') &&
              !line.contains('package:logger') &&
              !line.contains('dart:') &&
              !line.contains('layerx_debugger');
      spans.add(TextSpan(
        text: '$line\n',
        style: TextStyle(
          color: isProjectLine ? LxTheme.accentBlue : LxTheme.textDim,
          fontWeight: isProjectLine ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _statusLabel(int code) {
    const labels = {
      200: '200 OK',
      201: '201 Created',
      204: '204 No Content',
      301: '301 Moved',
      304: '304 Not Modified',
      400: '400 Bad Request',
      401: '401 Unauthorized',
      403: '403 Forbidden',
      404: '404 Not Found',
      405: '405 Method Not Allowed',
      408: '408 Request Timeout',
      409: '409 Conflict',
      422: '422 Unprocessable Entity',
      429: '429 Too Many Requests',
      500: '500 Internal Server Error',
      502: '502 Bad Gateway',
      503: '503 Service Unavailable',
      504: '504 Gateway Timeout',
    };
    return labels[code] ?? code.toString();
  }

  Future<void> _copyFullLog(BuildContext context, LayerXLogEntry log) async {
    final buffer = StringBuffer();
    buffer.writeln('=== LOG DETAIL EXPORT ===');
    buffer.writeln('Timestamp  : ${log.timestamp.toIso8601String()}');
    buffer.writeln('Level      : ${log.level.label}');
    buffer.writeln('Source     : ${log.source.label}');
    buffer.writeln('Message    : ${log.message}');
    if (log.endpoint != null) {
      buffer
          .writeln('Endpoint   : ${log.endpoint} [${log.statusCode ?? 'N/A'}]');
    }
    if (log.requestPayload != null) {
      buffer.writeln('Request:\n${log.requestPayload}');
    }
    if (log.responsePayload != null) {
      buffer.writeln('Response:\n${log.responsePayload}');
    }
    if (log.responseChanged && log.schemaChanges.isNotEmpty) {
      buffer.writeln('─── Schema Diff ───');
      for (final c in log.schemaChanges) {
        buffer.writeln(
            '[${c.label}] ${c.key}: ${c.previousValue ?? 'N/A'} → ${c.currentValue ?? 'N/A'}');
      }
    }
    if (log.stackTrace != null) {
      buffer.writeln('StackTrace:\n${log.stackTrace}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        LxTheme.snackBar('Log detail copied to clipboard ✓'),
      );
    }
  }
}
