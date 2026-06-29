import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';

/// A transparent logging decorator for **any** [http.Client].
///
/// Wrap your existing client — including an `IOClient`, a `RetryClient`, or the
/// default `http.Client()` — and every request made through it is captured by
/// LayerX with no other setup. Because `Client.get/post/put/patch/delete` and
/// `MultipartRequest.send` all funnel through [send], wrapping the one client
/// captures the whole API surface:
///
/// ```dart
/// // before
/// late final IOClient _client = IOClient(HttpClient()..connectionTimeout = ...);
/// // after — one line, every endpoint is now logged
/// late final http.Client _client =
///     LayerXHttpClient(IOClient(HttpClient()..connectionTimeout = ...));
/// ```
///
/// Logging is fully guarded: it never alters the request and the caller always
/// receives an intact response.
class LayerXHttpClient extends http.BaseClient {
  /// Creates a client that logs every exchange and delegates to [inner]
  /// (defaults to a fresh `http.Client()`).
  LayerXHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    final requestBody = _requestBody(request);

    try {
      final streamed = await _inner.send(request);

      // Buffer the body so it can be logged without consuming the caller's
      // stream, then hand back a fresh response built from the same bytes.
      final bytes = await streamed.stream.toBytes();
      stopwatch.stop();

      LayerXNetworkLogger.record(
        endpoint: request.url.toString(),
        method: request.method,
        statusCode: streamed.statusCode,
        responseBody: _decode(bytes),
        requestBody: requestBody,
        requestHeaders: request.headers,
        responseHeaders: streamed.headers,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        streamed.statusCode,
        contentLength: bytes.length,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      LayerXNetworkLogger.recordException(
        endpoint: request.url.toString(),
        method: request.method,
        error: error,
        stackTrace: stackTrace,
        requestBody: requestBody,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  /// Best-effort extraction of the request body for logging. Only plain
  /// [http.Request]s expose a body string; multipart/streamed bodies are left
  /// to the dedicated multipart handling and reported as `null`.
  static String? _requestBody(http.BaseRequest request) =>
      request is http.Request && request.body.isNotEmpty ? request.body : null;

  /// Decodes response bytes for logging, tolerating non-UTF8 payloads.
  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }
}
