import 'package:logger/logger.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';

/// A [LogOutput] implementation that forwards standard `package:logger` events
/// to the LayerX Debugger in-app viewer.
///
/// Use it in your custom `Logger` configuration to automatically record logs:
/// ```dart
/// final logger = Logger(
///   output: MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()]),
/// );
/// ```
class LayerXLogInterceptorOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    try {
      final logEvent = event.origin;
      final rawMessage = logEvent.message;
      final stackTrace = logEvent.stackTrace;
      final dateTime = logEvent.time;
      final level = logEvent.level;

      String messageStr = rawMessage.toString();

      // Avoid infinite loop if logging originates from LayerX's own ConsoleLogger
      if (messageStr.contains('[LayerX Debugger]') ||
          messageStr.contains('ROUTE PUSH') ||
          messageStr.contains('ROUTE POP') ||
          messageStr.contains('ROUTE REPLACE')) {
        return;
      }

      // Filter redundant or duplicate HTTP logs from standard Logger Service calls,
      // as they are fully captured by the intelligent HTTP interceptor.
      final normalizedMsg = messageStr.trim();
      if (normalizedMsg.startsWith('Sending get:') ||
          normalizedMsg.startsWith('Sending post:') ||
          normalizedMsg.startsWith('Sending put:') ||
          normalizedMsg.startsWith('Sending patch:') ||
          normalizedMsg.startsWith('Sending delete:') ||
          normalizedMsg.startsWith('Sending multipart:') ||
          normalizedMsg.startsWith('HTTP GET') ||
          normalizedMsg.startsWith('HTTP POST') ||
          normalizedMsg.startsWith('HTTP PUT') ||
          normalizedMsg.startsWith('HTTP PATCH') ||
          normalizedMsg.startsWith('HTTP DELETE') ||
          normalizedMsg.startsWith('Reusing active request:')) {
        return;
      }

      final levelEnum = _mapLevel(level);

      String? screen;
      String? method;
      String? controller;
      String? service;
      String? repo;
      String? endpoint;
      int? statusCode;
      String? requestPayload;
      String? responsePayload;
      String? errorCode;
      Map<String, dynamic> extras = {};

      if (rawMessage is Map<String, dynamic>) {
        messageStr = rawMessage['message']?.toString() ?? messageStr;
        screen = rawMessage['screen'] as String?;
        method = rawMessage['method'] as String?;
        controller = rawMessage['controller'] as String?;
        service = rawMessage['service'] as String?;
        repo = rawMessage['repo'] as String?;
        endpoint = rawMessage['endpoint'] as String?;
        statusCode = rawMessage['statusCode'] as int?;
        requestPayload = rawMessage['requestPayload'] as String?;
        responsePayload = rawMessage['responsePayload'] as String?;
        errorCode = rawMessage['errorCode'] as String?;
        if (rawMessage['extras'] is Map<String, dynamic>) {
          extras = Map<String, dynamic>.from(rawMessage['extras'] as Map);
        }
      }

      LayerXLogOutput.ingest(
        level: levelEnum,
        message: messageStr,
        screen: screen,
        method: method,
        controller: controller,
        service: service,
        repo: repo,
        endpoint: endpoint,
        statusCode: statusCode,
        requestPayload: requestPayload,
        responsePayload: responsePayload,
        errorCode: errorCode,
        extras: extras,
        error: logEvent.error,
        stackTrace: stackTrace,
        timestamp: dateTime,
      );
    } catch (_) {
      // Safe guard against external logger errors
    }
  }

  LayerXLogLevel _mapLevel(Level level) {
    switch (level) {
      case Level.trace:
        return LayerXLogLevel.verbose;
      case Level.debug:
        return LayerXLogLevel.debug;
      case Level.info:
        return LayerXLogLevel.info;
      case Level.warning:
        return LayerXLogLevel.warning;
      case Level.error:
        return LayerXLogLevel.error;
      case Level.fatal:
        return LayerXLogLevel.fatal;
      default:
        return LayerXLogLevel.debug;
    }
  }
}
