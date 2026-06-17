import 'package:get/get.dart';

import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';

/// A GetX service exposing manual network logging.
///
/// Useful for custom HTTP clients: adapt a response and call [record], or
/// [recordException] for transport failures.
class LayerXNetworkService extends GetxService {
  /// Records a completed HTTP exchange. See [LayerXNetworkLogger.record].
  void record({
    required String endpoint,
    required String method,
    required int statusCode,
    String? responseBody,
    String? requestBody,
    Map<String, String>? requestHeaders,
    Map<String, String>? responseHeaders,
    int durationMs = 0,
  }) {
    LayerXNetworkLogger.record(
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      responseBody: responseBody,
      requestBody: requestBody,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      durationMs: durationMs,
    );
  }

  /// Records a transport-level failure. See [LayerXNetworkLogger.recordException].
  void recordException({
    required String endpoint,
    required String method,
    required Object error,
    StackTrace? stackTrace,
    String? requestBody,
    int durationMs = 0,
  }) {
    LayerXNetworkLogger.recordException(
      endpoint: endpoint,
      method: method,
      error: error,
      stackTrace: stackTrace,
      requestBody: requestBody,
      durationMs: durationMs,
    );
  }
}
