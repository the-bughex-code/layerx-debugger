import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/utils/layerx_json_diff.dart';

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

  /// The canonical entry list. [logsNotifier] mirrors it, one frame behind at
  /// most — see [_notify].
  static final List<LayerXLogEntry> _logs = <LayerXLogEntry>[];

  static bool _notifyScheduled = false;

  /// The current entries, newest first. Always up to date, including entries
  /// whose listener notification is still pending.
  static List<LayerXLogEntry> get logs => List.unmodifiable(_logs);

  /// Publishes [_logs] to [logsNotifier] — never synchronously while a frame
  /// is building.
  ///
  /// Logs are emitted from anywhere, including the middle of the build phase
  /// (a controller's `onInit` while its route builds, `LayerXLog.screen()` in
  /// `build()`, a nested Navigator's initial `didPush`, a FlutterError reported
  /// during build). Notifying synchronously there runs `setState` on the
  /// always-mounted FAB listener mid-build — a framework error which the crash
  /// handler then re-ingests into this same notifier, recursing until the UI
  /// thread locks up. Deferring to a post-frame callback makes every producer
  /// phase-safe and coalesces bursts into a single notification per frame.
  static void _notify() {
    try {
      final binding = SchedulerBinding.instance;
      if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        if (_notifyScheduled) return;
        _notifyScheduled = true;
        binding.addPostFrameCallback((_) {
          _notifyScheduled = false;
          logsNotifier.value = List.unmodifiable(_logs);
        });
        return;
      }
    } catch (_) {
      // No binding (pure Dart test) — publish synchronously below.
    }
    logsNotifier.value = List.unmodifiable(_logs);
  }

  /// The number of `error` + `fatal` entries — used for the FAB badge.
  ///
  /// Counts iterate [_logs] directly (NOT the [logs] getter, which copies the
  /// whole list) — they run on every badge rebuild.
  static int get errorCount => _logs
      .where((log) =>
          log.level == LayerXLogLevel.error ||
          log.level == LayerXLogLevel.fatal)
      .length;

  /// The most recent entries scanned when collapsing duplicates. Bounds the
  /// per-ingest cost during floods; anything beyond this many arrivals inside
  /// the dedup window simply starts a fresh entry.
  static const int _dedupScanLimit = 200;

  /// Returns a recent entry with [dedupKey] whose timestamp is within [window]
  /// of [now], or `null`.
  ///
  /// This is the per-ingest duplicate lookup, so it must not allocate: it
  /// walks [_logs] in place (never the copying [logs] getter). Entries are
  /// newest-first by ingest time, so the walk stops at the first entry older
  /// than the window — a flood can't turn every ingest into a full scan.
  static LayerXLogEntry? findRecentByDedupKey(
    String dedupKey,
    DateTime now, {
    Duration window = const Duration(seconds: 2),
  }) {
    var scanned = 0;
    for (final log in _logs) {
      if (now.difference(log.timestamp) > window) break;
      if (++scanned > _dedupScanLimit) break;
      if (log.dedupKey == dedupKey &&
          now.difference(log.timestamp).abs() <= window) {
        return log;
      }
    }
    return null;
  }

  /// The minimum duration (ms) at which an otherwise-healthy entry is still
  /// counted as a problem — a slow request, even at success level. Configure
  /// this to match what "slow" means for your API before the viewer is shown.
  static int slowRequestThresholdMs = 800;

  /// Whether [log] is something a tester would report: an error, fatal,
  /// warning, an API response that changed shape, or a slow request.
  static bool isProblemEntry(LayerXLogEntry log) =>
      log.level == LayerXLogLevel.error ||
      log.level == LayerXLogLevel.fatal ||
      log.level == LayerXLogLevel.warning ||
      log.responseChanged ||
      _isSlow(log);

  /// Reads the entry's `duration_ms` extra directly (the store must not
  /// depend on view-layer helpers) and compares it against
  /// [slowRequestThresholdMs].
  static bool _isSlow(LayerXLogEntry log) {
    final duration = log.extras['duration_ms'];
    return duration is int && duration >= slowRequestThresholdMs;
  }

  /// The single source of truth for "how many problems are open" — used by the
  /// FAB badge, the header count, and the settings tile.
  static int get openProblemCount => _logs.where(isProblemEntry).length;

  /// The number of entries whose API response schema changed.
  static int get schemaChangeCount =>
      _logs.where((log) => log.responseChanged).length;

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

    _logs.insert(0, logToInsert);
    if (_logs.length > maxStoredLogs) {
      _logs.removeRange(maxStoredLogs, _logs.length);
    }
    _notify();
  }

  /// Replaces the entry with the same id as [updatedLog].
  static void updateLog(LayerXLogEntry updatedLog) {
    final index = _logs.indexWhere((log) => log.id == updatedLog.id);
    if (index != -1) {
      _logs[index] = updatedLog;
      _notify();
    }
  }

  /// Removes the entry with the given [id].
  static void deleteLog(String id) {
    _logs.removeWhere((log) => log.id == id);
    _notify();
  }

  /// Clears all entries and the per-endpoint response history.
  static void clear() {
    _logs.clear();
    _lastResponsesByEndpoint.clear();
    _notify();
  }

  /// Restores a previously captured snapshot (used by the clear-session Undo).
  static void restore(List<LayerXLogEntry> entries) {
    _logs
      ..clear()
      ..addAll(entries);
    _notify();
  }

  /// Renders all entries to a shareable plain-text report.
  static Future<String> exportLogsAsString() async {
    final entries = List<LayerXLogEntry>.from(_logs);
    final buffer = StringBuffer();
    buffer.writeln('=== LAYERX LOG EXPORT ===');
    buffer.writeln('Exported on: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Logs  : ${entries.length}');
    buffer.writeln(
        'Errors/Fatal: ${entries.where((l) => l.level == LayerXLogLevel.error || l.level == LayerXLogLevel.fatal).length}');
    buffer.writeln('Schema Diffs: $schemaChangeCount');
    buffer.writeln('─' * 60);

    for (final log in entries) {
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
