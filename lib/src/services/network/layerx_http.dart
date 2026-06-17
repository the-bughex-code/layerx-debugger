import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';

/// Thin logging wrappers around `package:http`.
///
/// Use these in place of the top-level `http` functions to get automatic
/// request/response logging with no other setup:
///
/// ```dart
/// final res = await LayerXHttp.get(Uri.parse('https://api.example.com/users'));
/// ```
class LayerXHttp {
  LayerXHttp._();

  /// The underlying client used for all requests. Swap it (e.g. for a
  /// `MockClient`) in tests.
  static http.Client client = http.Client();

  /// Performs a logged GET request.
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      _send('GET', url, headers: headers);

  /// Performs a logged POST request.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _send('POST', url, headers: headers, body: body, encoding: encoding);

  /// Performs a logged PUT request.
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _send('PUT', url, headers: headers, body: body, encoding: encoding);

  /// Performs a logged PATCH request.
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _send('PATCH', url, headers: headers, body: body, encoding: encoding);

  /// Performs a logged DELETE request.
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _send('DELETE', url, headers: headers, body: body, encoding: encoding);

  static Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = switch (method) {
        'POST' => await client.post(url,
            headers: headers, body: body, encoding: encoding),
        'PUT' => await client.put(url,
            headers: headers, body: body, encoding: encoding),
        'PATCH' => await client.patch(url,
            headers: headers, body: body, encoding: encoding),
        'DELETE' => await client.delete(url,
            headers: headers, body: body, encoding: encoding),
        _ => await client.get(url, headers: headers),
      };
      stopwatch.stop();
      LayerXNetworkLogger.record(
        endpoint: url.toString(),
        method: method,
        statusCode: response.statusCode,
        responseBody: response.body,
        requestBody: _bodyToString(body),
        requestHeaders: headers,
        responseHeaders: response.headers,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return response;
    } catch (error, stackTrace) {
      stopwatch.stop();
      LayerXNetworkLogger.recordException(
        endpoint: url.toString(),
        method: method,
        error: error,
        stackTrace: stackTrace,
        requestBody: _bodyToString(body),
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  static String? _bodyToString(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is Map || body is List) {
      try {
        return json.encode(body);
      } catch (_) {
        return body.toString();
      }
    }
    return body.toString();
  }
}
