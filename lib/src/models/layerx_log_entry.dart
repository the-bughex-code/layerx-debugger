import 'layerx_journey_step.dart';
import 'layerx_log_level.dart';
import 'layerx_log_source.dart';
import 'layerx_schema_change.dart';

/// A single, fully-structured log entry stored by LayerX.
///
/// Entries are produced by the logger, the network interceptors, the crash
/// handler and the navigation observer, then kept in memory by the log store
/// and rendered by the in-app viewer.
class LayerXLogEntry {
  /// A unique identifier for this entry.
  final String id;

  /// A stable key used to detect duplicate entries within a short time window.
  final String dedupKey;

  /// When the entry was created.
  final DateTime timestamp;

  /// The severity of the entry.
  final LayerXLogLevel level;

  /// The most likely origin of the entry.
  final LayerXLogSource source;

  /// The primary, human-readable message.
  final String message;

  /// The screen/route associated with the entry, when known.
  final String? screenName;

  /// The method or function associated with the entry, when known.
  final String? methodName;

  /// The controller associated with the entry, when known.
  final String? controllerName;

  /// The service associated with the entry, when known.
  final String? serviceName;

  /// The repository associated with the entry, when known.
  final String? repoName;

  /// The network endpoint associated with the entry, when known.
  final String? endpoint;

  /// The HTTP status code associated with the entry, when known.
  final int? statusCode;

  /// The (optionally pretty-printed) request payload, when known.
  final String? requestPayload;

  /// The (optionally pretty-printed) response payload, when known.
  final String? responsePayload;

  /// The captured stack trace as a string, when available.
  final String? stackTrace;

  /// A backend or application error code, when known.
  final String? errorCode;

  /// The reconstructed sequence of steps that led to this entry.
  final List<LayerXJourneyStep> journey;

  /// Arbitrary structured extras attached to the entry.
  final Map<String, dynamic> extras;

  /// An actionable fix suggestion produced by the solution engine, if any.
  final String? suggestedSolution;

  /// How many times an equivalent entry has occurred (incremented on dedup).
  int occurrenceCount;

  /// The timestamps of every occurrence tracked for this entry.
  final List<DateTime> repeatTimestamps;

  /// The raw response payload from the previous call to the same endpoint.
  final String? previousResponsePayload;

  /// Whether the response payload changed compared to the previous call.
  final bool responseChanged;

  /// The field-level diff versus the previous response, when [responseChanged].
  final List<LayerXSchemaChange> schemaChanges;

  /// Creates a log entry.
  LayerXLogEntry({
    required this.id,
    required this.dedupKey,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.screenName,
    this.methodName,
    this.controllerName,
    this.serviceName,
    this.repoName,
    this.endpoint,
    this.statusCode,
    this.requestPayload,
    this.responsePayload,
    this.stackTrace,
    this.errorCode,
    required this.journey,
    required this.extras,
    this.suggestedSolution,
    this.occurrenceCount = 1,
    List<DateTime>? repeatTimestamps,
    this.previousResponsePayload,
    this.responseChanged = false,
    List<LayerXSchemaChange>? schemaChanges,
  })  : repeatTimestamps = repeatTimestamps ?? [timestamp],
        schemaChanges = schemaChanges ?? [];

  /// Returns a copy of this entry with the given fields replaced.
  LayerXLogEntry copyWith({
    String? id,
    String? dedupKey,
    DateTime? timestamp,
    LayerXLogLevel? level,
    LayerXLogSource? source,
    String? message,
    String? screenName,
    String? methodName,
    String? controllerName,
    String? serviceName,
    String? repoName,
    String? endpoint,
    int? statusCode,
    String? requestPayload,
    String? responsePayload,
    String? stackTrace,
    String? errorCode,
    List<LayerXJourneyStep>? journey,
    Map<String, dynamic>? extras,
    String? suggestedSolution,
    int? occurrenceCount,
    List<DateTime>? repeatTimestamps,
    String? previousResponsePayload,
    bool? responseChanged,
    List<LayerXSchemaChange>? schemaChanges,
  }) {
    return LayerXLogEntry(
      id: id ?? this.id,
      dedupKey: dedupKey ?? this.dedupKey,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      source: source ?? this.source,
      message: message ?? this.message,
      screenName: screenName ?? this.screenName,
      methodName: methodName ?? this.methodName,
      controllerName: controllerName ?? this.controllerName,
      serviceName: serviceName ?? this.serviceName,
      repoName: repoName ?? this.repoName,
      endpoint: endpoint ?? this.endpoint,
      statusCode: statusCode ?? this.statusCode,
      requestPayload: requestPayload ?? this.requestPayload,
      responsePayload: responsePayload ?? this.responsePayload,
      stackTrace: stackTrace ?? this.stackTrace,
      errorCode: errorCode ?? this.errorCode,
      journey: journey ?? this.journey,
      extras: extras ?? this.extras,
      suggestedSolution: suggestedSolution ?? this.suggestedSolution,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      repeatTimestamps: repeatTimestamps ?? this.repeatTimestamps,
      previousResponsePayload:
          previousResponsePayload ?? this.previousResponsePayload,
      responseChanged: responseChanged ?? this.responseChanged,
      schemaChanges: schemaChanges ?? this.schemaChanges,
    );
  }
}
