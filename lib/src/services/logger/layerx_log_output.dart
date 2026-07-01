import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_journey_step.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/utils/layerx_duplicate_guard.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/utils/layerx_solution_engine.dart';
import 'package:layerx_debugger/src/config/utils/layerx_source_detector.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/utils/layerx_stack_location.dart';

/// Builds structured [LayerXLogEntry] records and writes them to the
/// [LayerXLogStore].
///
/// This is the single ingestion point used by [LayerXLog], the crash handler
/// and the network logger. It detects the source, attaches a fix suggestion for
/// errors, reconstructs the journey and collapses duplicates.
class LayerXLogOutput {
  LayerXLogOutput._();

  /// Creates a [LayerXLogEntry] from the given fields and stores it, collapsing
  /// duplicates that occur within a short window.
  static void ingest({
    required LayerXLogLevel level,
    required String message,
    LayerXLogCategory? category,
    String? screen,
    String? method,
    String? controller,
    String? service,
    String? repo,
    String? endpoint,
    int? statusCode,
    String? requestPayload,
    String? responsePayload,
    String? errorCode,
    Map<String, dynamic>? extras,
    Object? error,
    StackTrace? stackTrace,
    DateTime? timestamp,
    String? packageName,
  }) {
    try {
      final stackStr = stackTrace?.toString();
      final combined = error != null ? '$message\n$error' : message;
      final now = timestamp ?? DateTime.now();

      var resolvedScreen = screen;
      var resolvedMethod = method;
      if (resolvedScreen == null || resolvedMethod == null) {
        final parsed =
            _parseStackTrace(stackTrace ?? StackTrace.current, packageName);
        resolvedScreen ??= parsed['screen'];
        resolvedMethod ??= parsed['method'];
      }

      final source = LayerXSourceDetector.detect(
        statusCode: statusCode,
        message: combined,
        stackTrace: stackStr,
      );

      final location = LayerXStackLocation.parse(
        (stackTrace ?? StackTrace.current).toString(),
        packageName: packageName,
      );
      final resolvedCategory = category ??
          (endpoint != null
              ? LayerXLogCategory.api
              : LayerXLogCategory.app);

      String? solution;
      if (level == LayerXLogLevel.error || level == LayerXLogLevel.fatal) {
        solution = LayerXSolutionEngine.getSuggestion(combined, stackStr);
      }

      final journey = _buildJourney(
        screen: resolvedScreen,
        method: resolvedMethod,
        controller: controller,
        service: service,
        repo: repo,
        endpoint: endpoint,
        statusCode: statusCode,
        level: level,
        message: message,
        now: now,
      );

      final dedupKey = LayerXDuplicateGuard.generateKey(
        levelName: level.name,
        message: message,
        screenName: resolvedScreen,
        methodName: resolvedMethod,
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
        category: resolvedCategory,
        sourceFile: location.file,
        sourceLine: location.line,
        message: message,
        screenName: resolvedScreen,
        methodName: resolvedMethod,
        controllerName: controller,
        serviceName: service,
        repoName: repo,
        endpoint: endpoint,
        statusCode: statusCode,
        requestPayload: requestPayload,
        responsePayload: responsePayload,
        stackTrace: stackStr,
        errorCode: errorCode,
        journey: journey,
        extras: extras ?? {},
        suggestedSolution: solution,
      ));
    } catch (e, stack) {
      debugPrint('LayerXLogOutput.ingest failed: $e\n$stack');
    }
  }

  static Map<String, String?> _parseStackTrace(
    StackTrace trace,
    String? packageName,
  ) {
    try {
      final lines = trace.toString().split('\n');
      for (final line in lines) {
        if (line.contains('layerx_debugger') ||
            line.contains('layerx_log') ||
            line.contains('layerx_logger_service')) {
          continue;
        }
        if (packageName != null) {
          if (!line.contains('package:$packageName')) continue;
        } else {
          if (line.contains('dart:') ||
              line.contains('package:flutter') ||
              line.contains('package:logger')) {
            continue;
          }
          if (!line.contains('package:')) continue;
        }

        final match = RegExp(r'#\d+\s+([^\s]+)').firstMatch(line);
        if (match != null) {
          final symbol = match.group(1) ?? '';
          if (symbol.contains('.')) {
            final parts = symbol.split('.');
            return {'screen': parts[0], 'method': parts.sublist(1).join('.')};
          }
          return {'screen': null, 'method': symbol};
        }
      }
    } catch (_) {}
    return {'screen': null, 'method': null};
  }

  static List<LayerXJourneyStep> _buildJourney({
    String? screen,
    String? method,
    String? controller,
    String? service,
    String? repo,
    String? endpoint,
    int? statusCode,
    required LayerXLogLevel level,
    required String message,
    required DateTime now,
  }) {
    final journey = <LayerXJourneyStep>[];
    final isError =
        level == LayerXLogLevel.error || level == LayerXLogLevel.fatal;

    if (screen != null) {
      journey.add(LayerXJourneyStep(
        timestamp: now.subtract(const Duration(milliseconds: 100)),
        title: screen,
        description: 'Tapped / Entered Screen',
        type: 'ui',
      ));
    }
    if (controller != null) {
      journey.add(LayerXJourneyStep(
        timestamp: now.subtract(const Duration(milliseconds: 80)),
        title: controller,
        description:
            method != null ? 'Called $method()' : 'Invoked controller logic',
        type: 'controller',
      ));
    }
    if (service != null) {
      journey.add(LayerXJourneyStep(
        timestamp: now.subtract(const Duration(milliseconds: 60)),
        title: service,
        description: 'Called service method',
        type: 'service',
      ));
    }
    if (repo != null) {
      journey.add(LayerXJourneyStep(
        timestamp: now.subtract(const Duration(milliseconds: 40)),
        title: repo,
        description: 'Queried Repository',
        type: 'repository',
      ));
    }
    if (endpoint != null) {
      journey.add(LayerXJourneyStep(
        timestamp: now.subtract(const Duration(milliseconds: 20)),
        title: endpoint,
        description: statusCode != null
            ? 'API Response status $statusCode'
            : 'API Request made',
        type: 'network',
      ));
    }

    journey.add(LayerXJourneyStep(
      timestamp: now,
      title: isError
          ? 'Error Origin: ${statusCode ?? level.label}'
          : 'Log: ${level.label}',
      description: message,
      type: isError ? 'error' : 'log',
    ));

    return journey;
  }
}
