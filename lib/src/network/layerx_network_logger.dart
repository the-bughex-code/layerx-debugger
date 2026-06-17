import 'dart:convert';

import '../core/layerx_architecture_detector.dart';
import '../core/layerx_debugger.dart';
import '../logger/layerx_console_printer.dart';
import '../logger/layerx_log_output.dart';
import '../models/layerx_journey_step.dart';
import '../models/layerx_log_entry.dart';
import '../models/layerx_log_level.dart';
import '../models/layerx_log_source.dart';
import '../utils/layerx_duplicate_guard.dart';
import '../utils/layerx_log_store.dart';
import '../utils/layerx_solution_engine.dart';
import 'layerx_masker.dart';

/// The transport-agnostic core that turns an HTTP exchange into a structured
/// [LayerXLogEntry] and a colored console box.
///
/// Both [LayerXDioInterceptor] and [LayerXHttp] adapt their results into the
/// primitives [record] accepts, so the capture logic lives in one place.
class LayerXNetworkLogger {
  LayerXNetworkLogger._();

  static const List<String> _skipEndpoints = [
    '/socket.io',
    '/ws',
    '/ping',
    '/health',
    '/heartbeat',
    '/metrics',
    '/favicon',
  ];

  static const int _maxBodyChars = 4000;
  static const int _previewChars = 500;

  /// Records a completed HTTP exchange.
  ///
  /// `2xx` is logged as [LayerXLogLevel.success] (green), `4xx` as a warning,
  /// and `5xx` as an error. Sensitive fields in [requestBody], [responseBody]
  /// and [requestHeaders] are masked.
  static void record({
    required String endpoint,
    required String method,
    required int statusCode,
    String? responseBody,
    String? requestBody,
    Map<String, String>? requestHeaders,
    Map<String, String>? responseHeaders,
    int durationMs = 0,
  }) {
    final config = LayerXDebugger.config;
    if (!config.enableApiLogs) return;
    if (_skipEndpoints.any(endpoint.contains)) return;
    LayerXArchitectureDetector.markNetwork();

    final isError = statusCode >= 400;
    final isServerError = statusCode >= 500;
    final level = isServerError
        ? LayerXLogLevel.error
        : isError
            ? LayerXLogLevel.warning
            : LayerXLogLevel.success;

    if (level.index < config.environment.minimumLevel.index) return;

    try {
      final maskKeys = config.maskKeys;
      final reqPayload = requestBody == null
          ? null
          : LayerXMasker.maskJsonString(_clip(requestBody),
              extraKeys: maskKeys);
      final rawBody = responseBody ?? '';
      final respPayload =
          LayerXMasker.maskJsonString(_clip(rawBody), extraKeys: maskKeys);

      String? errorCode;
      String? backendMessage;
      try {
        final decoded = json.decode(rawBody);
        if (decoded is Map) {
          errorCode = decoded['error_code']?.toString() ??
              decoded['code']?.toString() ??
              decoded['errorCode']?.toString();
          backendMessage = decoded['message']?.toString() ??
              decoded['msg']?.toString() ??
              decoded['error']?.toString();
        }
      } catch (_) {}

      final shortEndpoint = _shortPath(endpoint);
      final message = isError
          ? '$method $shortEndpoint → $statusCode'
              '${backendMessage != null ? '\n$backendMessage' : ''}'
          : '$method $shortEndpoint → $statusCode (${durationMs}ms)';

      final source = isServerError
          ? LayerXLogSource.server
          : isError
              ? LayerXLogSource.backend
              : LayerXLogSource.network;

      final solution =
          isError ? LayerXSolutionEngine.getSuggestion(message, null) : null;

      _printBox(
        method: method,
        shortEndpoint: shortEndpoint,
        statusCode: statusCode,
        durationMs: durationMs,
        level: level,
        requestHeaders: requestHeaders == null
            ? null
            : LayerXMasker.maskHeaders(requestHeaders, extraKeys: maskKeys),
        requestPreview: reqPayload == null ? null : _preview(reqPayload),
        responsePreview: _preview(respPayload),
        colors: config.resolvedUseColors,
      );

      final now = DateTime.now();
      final journey = <LayerXJourneyStep>[
        LayerXJourneyStep(
          timestamp: now.subtract(Duration(milliseconds: durationMs)),
          title: '$method $shortEndpoint',
          description: 'Request sent',
          type: 'network',
        ),
        LayerXJourneyStep(
          timestamp: now,
          title: 'HTTP $statusCode',
          description: isError
              ? '${_httpStatusText(statusCode)}${backendMessage != null ? ' — $backendMessage' : ''}'
              : 'Response received in ${durationMs}ms',
          type: isError ? 'error' : 'network',
        ),
      ];

      final dedupKey = LayerXDuplicateGuard.generateKey(
        levelName: level.name,
        message: message,
        screenName: shortEndpoint,
        methodName: method,
      );
      final duplicate = LayerXDuplicateGuard.findDuplicate(dedupKey, now);
      if (duplicate != null) {
        duplicate.occurrenceCount++;
        duplicate.repeatTimestamps.add(now);
        LayerXLogStore.updateLog(duplicate);
        return;
      }

      LayerXLogStore.add(LayerXLogEntry(
        id: now.microsecondsSinceEpoch.toString(),
        dedupKey: dedupKey,
        timestamp: now,
        level: level,
        source: source,
        message: message,
        methodName: method,
        serviceName: 'HTTP',
        endpoint: endpoint,
        statusCode: statusCode,
        requestPayload: reqPayload,
        responsePayload: respPayload,
        errorCode: errorCode,
        journey: journey,
        extras: {
          'duration_ms': durationMs,
          'content_length': rawBody.length,
          if (responseHeaders?['content-type'] != null)
            'content_type': responseHeaders!['content-type']!,
        },
        suggestedSolution: solution,
      ));
    } catch (_) {
      // Never let logging break the request.
    }
  }

  /// Records a transport-level failure that produced no HTTP response (DNS
  /// failure, timeout, connection refused, …).
  static void recordException({
    required String endpoint,
    required String method,
    required Object error,
    StackTrace? stackTrace,
    String? requestBody,
    int durationMs = 0,
  }) {
    final config = LayerXDebugger.config;
    if (!config.enableApiLogs) return;
    if (_skipEndpoints.any(endpoint.contains)) return;
    LayerXArchitectureDetector.markNetwork();

    final shortEndpoint = _shortPath(endpoint);
    final message = '$method $shortEndpoint → $error';

    LayerXConsolePrinter.printBox(
      title: '$method $shortEndpoint',
      lines: ['Transport error', error.toString()],
      level: LayerXLogLevel.error,
      colors: config.resolvedUseColors,
    );

    LayerXLogOutput.ingest(
      level: LayerXLogLevel.error,
      message: message,
      endpoint: endpoint,
      method: method,
      requestPayload: requestBody == null
          ? null
          : LayerXMasker.maskJsonString(_clip(requestBody),
              extraKeys: config.maskKeys),
      error: error,
      stackTrace: stackTrace,
      extras: {'duration_ms': durationMs},
      packageName: config.packageName,
    );
  }

  static void _printBox({
    required String method,
    required String shortEndpoint,
    required int statusCode,
    required int durationMs,
    required LayerXLogLevel level,
    Map<String, String>? requestHeaders,
    String? requestPreview,
    required String responsePreview,
    required bool colors,
  }) {
    LayerXConsolePrinter.printBox(
      title: 'API $method $shortEndpoint',
      lines: [
        'Status   : $statusCode ${_httpStatusText(statusCode)} • ${durationMs}ms',
        if (requestHeaders != null && requestHeaders.isNotEmpty)
          'Headers  : $requestHeaders',
        if (requestPreview != null) 'Request  : $requestPreview',
        'Response : $responsePreview',
      ],
      level: level,
      colors: colors,
    );
  }

  static String _clip(String body) =>
      body.length > _maxBodyChars ? body.substring(0, _maxBodyChars) : body;

  static String _preview(String body) => body.length > _previewChars
      ? '${body.substring(0, _previewChars)}…'
      : body;

  static String _shortPath(String endpoint) {
    final idx = endpoint.indexOf('?');
    return idx == -1 ? endpoint : endpoint.substring(0, idx);
  }

  static String _httpStatusText(int code) {
    const map = {
      200: 'OK',
      201: 'Created',
      204: 'No Content',
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      405: 'Method Not Allowed',
      408: 'Request Timeout',
      409: 'Conflict',
      410: 'Gone',
      422: 'Unprocessable Entity',
      429: 'Too Many Requests',
      500: 'Internal Server Error',
      502: 'Bad Gateway',
      503: 'Service Unavailable',
      504: 'Gateway Timeout',
    };
    return map[code] ?? '';
  }
}
