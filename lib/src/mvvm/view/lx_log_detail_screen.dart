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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Log Detail'),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, color: Colors.black54),
            tooltip: 'Copy full log',
            onPressed: () => _copyFullLog(context, log),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
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
                    const SizedBox(height: 8),
                    _buildSchemaDiffTable(log),
                  ],
                  if (log.responseChanged &&
                      log.previousResponsePayload != null) ...[
                    const SizedBox(height: 12),
                    _sectionDivider('Previous Response (Before Change)'),
                    _jsonWidget(
                        log.previousResponsePayload!, _showFullPrevResponse,
                        tint: const Color(0xFFFFF3E0), onToggle: () {
                      setState(
                          () => _showFullPrevResponse = !_showFullPrevResponse);
                    }),
                    const SizedBox(height: 12),
                    _sectionDivider('Current Response (After Change)'),
                    _jsonWidget(log.responsePayload!, _showFullResponse,
                        tint: const Color(0xFFF1F8E9), onToggle: () {
                      setState(() => _showFullResponse = !_showFullResponse);
                    }),
                  ] else if (log.responsePayload != null) ...[
                    const SizedBox(height: 12),
                    _sectionDivider('Response Payload'),
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
                        const Icon(Icons.repeat, size: 14, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          formatted,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: idx == 0
                                ? Colors.grey.shade300
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: idx == 0
                                  ? Colors.grey.shade700
                                  : Colors.amber.shade900,
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: log.level.color.withValues(alpha: 0.3), width: 1.5),
      ),
      color: log.level.backgroundColor ?? Colors.white,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: log.level.color,
                        ),
                      ),
                      if (log.message.contains('\n')) ...[
                        const SizedBox(height: 6),
                        Text(
                          log.message.substring(log.message.indexOf('\n') + 1),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                LxSourceChip(source: log.source),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.level.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.level.label,
                    style: const TextStyle(
                      color: Colors.white,
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
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 10, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'API CHANGED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '×$totalOccurrences occurrences',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: blameInfo.color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: blameInfo.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(blameInfo.icon, color: blameInfo.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WHO OWNS THIS BUG?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: blameInfo.color,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              blameInfo.responsibleParty,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: blameInfo.color,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: blameInfo.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                blameInfo.explanation,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 14, color: blameInfo.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blameInfo.qaNote,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: blameInfo.color,
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
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ API RESPONSE CHANGED',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The response payload for "${log.endpoint ?? 'this endpoint'}" '
            'has changed since the previous call.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade900,
              height: 1.4,
            ),
          ),
          if (changeCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (addedCount > 0)
                  _diffBadge('+$addedCount added', const Color(0xFF2E7D32),
                      const Color(0xFFE8F5E9)),
                if (removedCount > 0)
                  _diffBadge('-$removedCount removed', const Color(0xFFC62828),
                      const Color(0xFFFFEBEE)),
                if (typeChangedCount > 0)
                  _diffBadge('$typeChangedCount type changed',
                      const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
                if (changeCount - addedCount - removedCount - typeChangedCount >
                    0)
                  _diffBadge(
                    '${changeCount - addedCount - removedCount - typeChangedCount} values changed',
                    const Color(0xFFE65100),
                    const Color(0xFFFFF8E1),
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
      LayerXSchemaDiffType.added: Color(0xFF2E7D32),
      LayerXSchemaDiffType.removed: Color(0xFFC62828),
      LayerXSchemaDiffType.typeChanged: Color(0xFF6A1B9A),
      LayerXSchemaDiffType.valueChanged: Color(0xFFE65100),
    };
    const diffBgColors = {
      LayerXSchemaDiffType.added: Color(0xFFE8F5E9),
      LayerXSchemaDiffType.removed: Color(0xFFFFEBEE),
      LayerXSchemaDiffType.typeChanged: Color(0xFFF3E5F5),
      LayerXSchemaDiffType.valueChanged: Color(0xFFFFF8E1),
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
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_outlined,
                  size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'SCHEMA DIFF — ${log.schemaChanges.length} field${log.schemaChanges.length > 1 ? 's' : ''} changed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showSchemaDiff = !_showSchemaDiff),
                child: Text(
                  _showSchemaDiff ? 'Hide' : 'Show',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSchemaDiff)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
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
                final bgColor = diffBgColors[change.diffType]!;
                final icon = diffIcons[change.diffType]!;
                final isLast = idx == log.schemaChanges.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
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
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          icon,
                          style: const TextStyle(
                            color: Colors.white,
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
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
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
                                  Colors.red.shade800, const Color(0xFFFFCDD2)),
                            ],
                            if (change.currentValue != null) ...[
                              const SizedBox(height: 3),
                              _valueRow(
                                  'After',
                                  change.currentValue!,
                                  Colors.green.shade800,
                                  const Color(0xFFC8E6C9)),
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

  Widget _valueRow(String label, String value, Color textColor, Color bgColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
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
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      color: Colors.white,
      child: ExpansionTile(
        initiallyExpanded: _showStackTrace,
        title: const Text(
          'Stack Trace',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: const Icon(Icons.code, color: Colors.blueGrey),
        trailing: TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: log.stackTrace!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stack trace copied to clipboard! 📋'),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 12),
          label: const Text('Copy', style: TextStyle(fontSize: 11)),
        ),
        onExpansionChanged: (val) => setState(() => _showStackTrace = val),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildStackTraceText(log.stackTrace!),
              ),
            ),
          ),
        ],
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
          SnackBar(content: Text('Copied "$label" to clipboard! 📋')),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '── $label ──────────────────────',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _jsonWidget(
    String rawJson,
    bool showFull, {
    Color? tint,
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
            color: tint ?? Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
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
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _diffBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  List<TextSpan> _highlightJson(String rawJson) {
    final spans = <TextSpan>[];
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
          style: const TextStyle(
            color: Colors.black87,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ));
      }

      final token = match.group(0)!;
      var style = const TextStyle(
        color: Colors.black87,
        fontFamily: 'monospace',
        fontSize: 11,
      );

      if (token.startsWith('"')) {
        style = token.endsWith(':')
            ? const TextStyle(
                color: Color(0xFF7B1FA2),
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 11,
              )
            : const TextStyle(
                color: Color(0xFF2E7D32),
                fontFamily: 'monospace',
                fontSize: 11,
              );
      } else if (token == 'true' || token == 'false') {
        style = const TextStyle(
          color: Color(0xFF1565C0),
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          fontSize: 11,
        );
      } else if (token == 'null') {
        style = const TextStyle(
          color: Color(0xFFC62828),
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          fontSize: 11,
        );
      } else if (RegExp(r'^-?\d+').hasMatch(token)) {
        style = const TextStyle(
          color: Color(0xFFE65100),
          fontFamily: 'monospace',
          fontSize: 11,
        );
      } else if (RegExp(r'[{}\[\]:,]').hasMatch(token)) {
        style = const TextStyle(
          color: Colors.grey,
          fontFamily: 'monospace',
          fontSize: 11,
        );
      }

      spans.add(TextSpan(text: token, style: style));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < rawJson.length) {
      spans.add(TextSpan(
        text: rawJson.substring(lastMatchEnd),
        style: const TextStyle(
          color: Colors.black87,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
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
          color: isProjectLine ? Colors.blue.shade900 : Colors.grey.shade500,
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
        const SnackBar(
          content: Text('Log detail copied to clipboard! 📋'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
