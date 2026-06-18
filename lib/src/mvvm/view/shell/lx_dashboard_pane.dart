// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';

/// The "Dashboard" destination — a session health overview.
class LxDashboardPane extends StatelessWidget {
  final List<LayerXLogEntry> logs;
  final ValueChanged<LayerXLogEntry> onInspect;

  const LxDashboardPane({
    super.key,
    required this.logs,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final network = logs.where(LxKit.isNetwork).toList();
    final errors = logs
        .where((l) =>
            l.level == LayerXLogLevel.error || l.level == LayerXLogLevel.fatal)
        .length;
    final warnings =
        logs.where((l) => l.level == LayerXLogLevel.warning).length;
    final schemaChanges = logs.where((l) => l.responseChanged).length;

    final durations =
        network.map(LxKit.durationOf).whereType<int>().toList();
    final avgLatency = durations.isEmpty
        ? 0
        : (durations.reduce((a, b) => a + b) / durations.length).round();

    final score = _healthScore(
      total: logs.length,
      errors: errors,
      warnings: warnings,
      schemaChanges: schemaChanges,
    );

    final issues = logs.where(LxKit.isProblem).take(6).toList();

    if (logs.isEmpty) {
      return LxKit.emptyState(
        Icons.dashboard_outlined,
        'NO ACTIVITY YET',
        'Interact with the app to populate the dashboard.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _healthHero(score, errors, warnings, schemaChanges),
        const SizedBox(height: 12),
        _metricsGrid(network.length, errors, avgLatency, schemaChanges),
        const SizedBox(height: 12),
        if (durations.isNotEmpty) _latencyCard(network),
        const SizedBox(height: 18),
        LxKit.sectionLabel('RECENT ISSUES'),
        if (issues.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: LxTheme.card(),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: LxTheme.accentGreen, size: 18),
                const SizedBox(width: 10),
                Text('No errors or warnings this session.',
                    style: LxTheme.bodySecondary),
              ],
            ),
          )
        else
          ...issues.map(_issueRow),
      ],
    );
  }

  int _healthScore({
    required int total,
    required int errors,
    required int warnings,
    required int schemaChanges,
  }) {
    if (total == 0) return 100;
    final penalty = errors * 18 + warnings * 6 + schemaChanges * 8;
    return (100 - penalty).clamp(0, 100);
  }

  Widget _healthHero(int score, int errors, int warnings, int schemaChanges) {
    final color = score >= 80
        ? LxTheme.accentGreen
        : score >= 50
            ? LxTheme.accentAmber
            : LxTheme.accentRed;
    final label = score >= 80
        ? 'Session healthy'
        : score >= 50
            ? 'Minor issues'
            : 'Needs attention';
    final parts = <String>[
      if (errors > 0) '$errors error${errors == 1 ? '' : 's'}',
      if (warnings > 0) '$warnings warning${warnings == 1 ? '' : 's'}',
      if (schemaChanges > 0) '$schemaChanges contract change${schemaChanges == 1 ? '' : 's'}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LxTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: LxTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: LxTheme.bodyPrimary
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  parts.isEmpty ? 'All systems nominal' : parts.join('  ·  '),
                  style: LxTheme.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(int requests, int errors, int avgLatency, int schema) {
    final cells = [
      _Metric('REQUESTS', '$requests', LxTheme.textPrimary),
      _Metric('ERRORS', '$errors', errors > 0 ? LxTheme.accentRed : LxTheme.textPrimary),
      _Metric('AVG LATENCY', avgLatency == 0 ? '—' : '${avgLatency}ms', LxTheme.accentBlue),
      _Metric('SCHEMA Δ', '$schema', schema > 0 ? LxTheme.accentOrange : LxTheme.textPrimary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: cells.map(_metricCard).toList(),
    );
  }

  Widget _metricCard(_Metric m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LxTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(m.label, style: LxTheme.monoSm),
          const SizedBox(height: 4),
          Text(
            m.value,
            style: TextStyle(
              color: m.color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latencyCard(List<LayerXLogEntry> network) {
    final recent = network.take(24).toList().reversed.toList();
    final durs = recent.map(LxKit.durationOf).map((d) => d ?? 0).toList();
    final maxDur = durs.isEmpty ? 1 : durs.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LxTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LxTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATENCY · LAST ${recent.length} CALLS', style: LxTheme.sectionLabel),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in recent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        height: maxDur == 0
                            ? 4
                            : (46 * ((LxKit.durationOf(e) ?? 0) / maxDur))
                                .clamp(4, 46),
                        decoration: BoxDecoration(
                          color: LxKit.statusColor(e.statusCode),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueRow(LayerXLogEntry e) {
    final rail = e.responseChanged ? LxTheme.accentOrange : e.level.color;
    final icon = e.responseChanged
        ? Icons.published_with_changes
        : LxKit.levelIcon(e.level);
    final title = e.responseChanged
        ? 'Response contract changed'
        : (LxKit.isNetwork(e)
            ? '${e.statusCode ?? ''} · ${LxKit.shortPath(e.endpoint)}'
            : e.message.split('\n').first);
    final sub = [
      if (e.controllerName != null) e.controllerName!,
      if (e.serviceName != null && e.serviceName != 'HTTP') e.serviceName!,
      if (LxKit.isNetwork(e) && e.endpoint != null) LxKit.shortPath(e.endpoint),
      if (e.occurrenceCount > 1) '×${e.occurrenceCount}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          onTap: () => onInspect(e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: LxKit.railCard(rail),
            child: Row(
              children: [
                Icon(icon, color: rail, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LxTheme.bodyPrimary.copyWith(fontSize: 13)),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LxTheme.monoSm),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: LxTheme.textDim, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final Color color;
  _Metric(this.label, this.value, this.color);
}
