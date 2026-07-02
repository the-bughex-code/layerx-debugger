import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';

/// Formats a single [LayerXLogEntry] into a complete, plain-language bug
/// report a QA tester can paste into a ticket.
///
/// This is the one formatter every "Copy bug report" action calls, so a report
/// always has the same shape: title → who's affected → status → when →
/// request → response → contract changes → suggested fix → triage note →
/// stack trace.
class LayerXReportFormatter {
  LayerXReportFormatter._();

  /// Renders the shareable report for [log].
  static String formatIssue(LayerXLogEntry log) {
    final b = StringBuffer()
      ..writeln('── Bug report ──')
      ..writeln(log.message.split('\n').first)
      ..writeln()
      ..writeln('Where: ${log.source.label}'
          '${log.endpoint != null ? ' · ${log.endpoint}' : ''}');
    if (log.statusCode != null) b.writeln('Status: ${log.statusCode}');
    b.writeln('When: ${relativeTime(log.timestamp)} '
        '(${log.timestamp.toIso8601String()})');
    if (log.occurrenceCount > 1) {
      b.writeln('Happened ${log.occurrenceCount} times');
    }
    if (log.requestPayload != null) {
      b
        ..writeln()
        ..writeln('What the app sent (request):')
        ..writeln(log.requestPayload);
    }
    if (log.responsePayload != null) {
      b
        ..writeln()
        ..writeln('What the server answered (response):')
        ..writeln(log.responsePayload);
    }
    if (log.responseChanged && log.schemaChanges.isNotEmpty) {
      b
        ..writeln()
        ..writeln('⚠️ The API response changed since the previous call:');
      for (final c in log.schemaChanges) {
        b.writeln('  [${c.label}] ${c.key}: '
            '${c.previousValue ?? '—'} → ${c.currentValue ?? '—'}');
      }
    }
    if (log.suggestedSolution != null) {
      b
        ..writeln()
        ..writeln('Suggested fix: ${log.suggestedSolution}');
    }
    final blame = LayerXBlameEngine.analyze(log);
    if (blame != null) {
      b
        ..writeln()
        ..writeln('Most likely owner: ${blame.responsibleParty}')
        ..writeln('Triage note: ${blame.qaNote}');
    }
    if (log.stackTrace != null &&
        (log.level == LayerXLogLevel.warning ||
            log.level == LayerXLogLevel.error ||
            log.level == LayerXLogLevel.fatal)) {
      b
        ..writeln()
        ..writeln('Stack trace (for the developer):')
        ..writeln(log.stackTrace);
    }
    return b.toString();
  }

  /// "just now", "5m ago", "3h ago", or "2d ago".
  static String relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
