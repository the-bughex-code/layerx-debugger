import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/layerx_log_entry.dart';
import '../models/layerx_log_level.dart';
import 'layerx_json_diff.dart';

/// The global, in-memory store of every captured [LayerXLogEntry].
///
/// The store is a passive data structure: producers (the logger, interceptors,
/// crash handler and route observers) decide *whether* to record based on the
/// active configuration, while the store decides *how* to keep entries. It
/// exposes a [logsNotifier] the in-app viewer listens to, and detects API
/// response changes for the same endpoint via [LayerXJsonDiff].
class LayerXLogStore {
  LayerXLogStore._();

  /// The maximum number of entries kept in memory. Oldest entries are trimmed.
  static int maxStoredLogs = 500;

  /// A listenable holding the current list of entries (newest first).
  static final ValueNotifier<List<LayerXLogEntry>> logsNotifier =
      ValueNotifier<List<LayerXLogEntry>>([]);

  /// The current entries, newest first.
  static List<LayerXLogEntry> get logs => logsNotifier.value;

  /// The number of `error` + `fatal` entries — used for the FAB badge.
  static int get errorCount => logs
      .where((log) =>
          log.level == LayerXLogLevel.error ||
          log.level == LayerXLogLevel.fatal)
      .length;

  /// The number of entries whose API response schema changed.
  static int get schemaChangeCount =>
      logs.where((log) => log.responseChanged).length;

  static final Map<String, String> _lastResponsesByEndpoint = {};

  /// Inserts [log] at the front of the store.
  ///
  /// When the entry carries an endpoint + response payload, the store compares
  /// it with the previous response for the same (normalised) endpoint and, if
  /// it changed, records the field-level diff on the inserted entry.
  static void add(LayerXLogEntry log) {
    var logToInsert = log;

    if (log.endpoint != null && log.responsePayload != null) {
      final endpointKey = LayerXJsonDiff.normaliseEndpointKey(log.endpoint!);
      final prevResponse = _lastResponsesByEndpoint[endpointKey];

      if (prevResponse != null && prevResponse != log.responsePayload) {
        final changes = LayerXJsonDiff.diff(prevResponse, log.responsePayload!);
        logToInsert = log.copyWith(
          previousResponsePayload: prevResponse,
          responseChanged: true,
          schemaChanges: changes,
        );
      }
      _lastResponsesByEndpoint[endpointKey] = log.responsePayload!;
    }

    final currentList = List<LayerXLogEntry>.from(logsNotifier.value);
    currentList.insert(0, logToInsert);
    if (currentList.length > maxStoredLogs) {
      currentList.removeRange(maxStoredLogs, currentList.length);
    }
    logsNotifier.value = currentList;
  }

  /// Replaces the entry with the same id as [updatedLog].
  static void updateLog(LayerXLogEntry updatedLog) {
    final currentList = List<LayerXLogEntry>.from(logsNotifier.value);
    final index = currentList.indexWhere((log) => log.id == updatedLog.id);
    if (index != -1) {
      currentList[index] = updatedLog;
      logsNotifier.value = currentList;
    }
  }

  /// Removes the entry with the given [id].
  static void deleteLog(String id) {
    final currentList = List<LayerXLogEntry>.from(logsNotifier.value);
    currentList.removeWhere((log) => log.id == id);
    logsNotifier.value = currentList;
  }

  /// Clears all entries and the per-endpoint response history.
  static void clear() {
    logsNotifier.value = [];
    _lastResponsesByEndpoint.clear();
  }

  /// Renders all entries to a shareable plain-text report.
  static Future<String> exportLogsAsString() async {
    final buffer = StringBuffer();
    buffer.writeln('=== LAYERX LOG EXPORT ===');
    buffer.writeln('Exported on: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Logs  : ${logs.length}');
    buffer.writeln(
        'Errors/Fatal: ${logs.where((l) => l.level == LayerXLogLevel.error || l.level == LayerXLogLevel.fatal).length}');
    buffer.writeln('Schema Diffs: $schemaChangeCount');
    buffer.writeln('─' * 60);

    for (final log in logs) {
      buffer.writeln(
          '[${log.timestamp.toIso8601String()}] [${log.level.label}] [${log.source.label}]');
      if (log.screenName != null || log.methodName != null) {
        buffer.writeln(
            'Location: ${log.screenName ?? ''} → ${log.methodName ?? ''}');
      }
      buffer.writeln('Message: ${log.message}');
      if (log.occurrenceCount > 1) {
        buffer.writeln('Occurrences: ${log.occurrenceCount}');
        buffer.writeln(
            'Times: ${log.repeatTimestamps.map((t) => t.toIso8601String()).join(', ')}');
      }
      if (log.endpoint != null) {
        buffer.writeln(
            'Endpoint: ${log.endpoint} (Status: ${log.statusCode ?? 'N/A'})');
      }
      if (log.errorCode != null) {
        buffer.writeln('Error Code: ${log.errorCode}');
      }
      if (log.requestPayload != null) {
        buffer.writeln('Request Payload:\n${log.requestPayload}');
      }
      if (log.responsePayload != null) {
        buffer.writeln('Response Payload:\n${log.responsePayload}');
      }
      if (log.responseChanged) {
        buffer.writeln('⚠️  API RESPONSE CHANGED from previous call!');
        if (log.schemaChanges.isNotEmpty) {
          buffer.writeln('Schema Diff:');
          for (final change in log.schemaChanges) {
            buffer.writeln(
                '  [${change.label}] ${change.key}: ${change.previousValue ?? 'N/A'} → ${change.currentValue ?? 'N/A'}');
          }
        }
        if (log.previousResponsePayload != null) {
          buffer.writeln('Previous Response:\n${log.previousResponsePayload}');
        }
      }
      if (log.suggestedSolution != null) {
        buffer.writeln('Suggested Fix: ${log.suggestedSolution}');
      }
      if (log.stackTrace != null) {
        buffer.writeln('StackTrace:\n${log.stackTrace}');
      }
      buffer.writeln('─' * 60);
    }
    return buffer.toString();
  }

  /// Exports all entries (see [exportLogsAsString]) to the system clipboard.
  static Future<void> copyExportToClipboard() async {
    final exportString = await exportLogsAsString();
    await Clipboard.setData(ClipboardData(text: exportString));
  }
}
