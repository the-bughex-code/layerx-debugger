import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';

/// A Dio [Interceptor] that forwards responses and transport errors to the
/// LayerX Debugger.
///
/// Opt in via `package:layerx_debugger/dio.dart`:
/// ```dart
/// dio.interceptors.add(LayerXDioInterceptor());
/// ```
class LayerXDioInterceptor extends Interceptor {
  final _starts = <int, DateTime>{};

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    _starts[options.hashCode] = DateTime.now();
    handler.next(options);
  }

  int _elapsed(RequestOptions o) {
    final start = _starts.remove(o.hashCode);
    return start == null
        ? 0
        : DateTime.now().difference(start).inMilliseconds;
  }

  String? _stringify(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    LayerXNetworkLogger.record(
      endpoint: o.uri.toString(),
      method: o.method,
      statusCode: response.statusCode ?? 0,
      responseBody: _stringify(response.data),
      requestBody: _stringify(o.data),
      requestHeaders: o.headers.map((k, v) => MapEntry(k, '$v')),
      responseHeaders:
          response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      durationMs: _elapsed(o),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final resp = err.response;
    if (resp != null) {
      LayerXNetworkLogger.record(
        endpoint: o.uri.toString(),
        method: o.method,
        statusCode: resp.statusCode ?? 0,
        responseBody: _stringify(resp.data),
        requestBody: _stringify(o.data),
        durationMs: _elapsed(o),
      );
    } else {
      LayerXNetworkLogger.recordException(
        endpoint: o.uri.toString(),
        method: o.method,
        error: err,
        stackTrace: err.stackTrace,
        requestBody: _stringify(o.data),
        durationMs: _elapsed(o),
      );
    }
    handler.next(err);
  }
}
