import 'dart:io';

import '../utils/cli_printer.dart';

/// Integrates LoggerService and HttpsCalls with LayerX Debugger if they exist.
///
/// Handles LayerX-architecture projects that embed a legacy `debug_logger/`
/// folder (LxLogOutput / LxHttpInterceptor) by replacing those references with
/// the canonical `layerx_debugger` package equivalents.
class ServiceLoggerHttpStep {
  final String projectRoot;

  ServiceLoggerHttpStep(this.projectRoot);

  bool run() {
    CliPrinter.step('Inspecting LayerX services for binding ...');

    final loggerModified = _patchLoggerService();
    final httpModified = _patchHttpsCalls();
    _cleanOldDebugLogger();

    if (loggerModified || httpModified) {
      CliPrinter.success('Services binding completed successfully!');
      return true;
    } else {
      CliPrinter.info(
        'No LoggerService or HttpsCalls modified (already bound or not found).',
      );
      return false;
    }
  }

  // ── LoggerService ─────────────────────────────────────────────────────────

  bool _patchLoggerService() {
    final loggerFile = File(
      '$projectRoot/lib/app/services/logger_service.dart',
    );
    if (!loggerFile.existsSync()) {
      CliPrinter.info('logger_service.dart not found — skipping.');
      return false;
    }

    var content = loggerFile.readAsStringSync();
    bool modified = false;

    // ── 1. Remove old debug_logger imports ───────────────────────────────────
    final oldLxImports = RegExp(
      r"import\s+'[^']*(?:debug_logger|lx_log_output)[^']*';\n?",
    );
    if (content.contains(oldLxImports)) {
      content = content.replaceAll(oldLxImports, '');
      modified = true;
    }

    // ── 2. Add debugger package import if missing ─────────────────────────────
    final debuggerImport =
        "import 'package:layerx_debugger/layerx_debugger.dart';";
    if (!content.contains(debuggerImport)) {
      final loggerImport = "import 'package:logger/logger.dart';";
      if (content.contains(loggerImport)) {
        content = content.replaceFirst(
          loggerImport,
          '$loggerImport\n$debuggerImport',
        );
      } else {
        content = '$debuggerImport\n$content';
      }
      modified = true;
    }

    // ── 3. Replace LxLogOutput() → LayerXLogInterceptorOutput() ──────────────
    if (content.contains('LxLogOutput()')) {
      content = content.replaceAll(
        'LxLogOutput()',
        'LayerXLogInterceptorOutput()',
      );
      modified = true;
    }

    // ── 4. If no LayerXLogInterceptorOutput yet, inject output into Logger() ─
    //
    // Strategy: work line-by-line to find the Logger constructor's closing ");".
    // Then insert the output parameter right before it. This avoids all the
    // multiline regex pitfalls (stray commas, broken formatting).
    if (!content.contains('LayerXLogInterceptorOutput')) {
      final lines = content.split('\n');
      final buf = StringBuffer();

      // Phase 1: locate the Logger(...) field declaration range.
      int loggerStart = -1; // line index of "static final Logger _logger = Logger("
      int loggerEnd = -1;   // line index of the closing ");"
      bool hasOutputParam = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (loggerStart == -1 &&
            line.contains('static') &&
            line.contains('Logger') &&
            line.contains('_logger') &&
            line.contains('Logger(')) {
          loggerStart = i;
        }
        if (loggerStart != -1 && loggerEnd == -1) {
          if (line.contains('output:')) hasOutputParam = true;
          // The closing ); can be on its own line or after the last param.
          if (line.trimRight().endsWith(');')) {
            loggerEnd = i;
          }
        }
      }

      if (loggerStart != -1 && loggerEnd != -1 && !hasOutputParam) {
        // We need to inject the output param before the closing );
        for (int i = 0; i < lines.length; i++) {
          if (i == loggerEnd) {
            // The closing line is something like "  );" or "    level: ...,\n  );"
            final closingLine = lines[i];
            final closingTrimmed = closingLine.trimRight();

            if (closingTrimmed == ');') {
              // Standalone ");": the previous line should already have a trailing comma.
              // Ensure it does, then add our output param.
              if (i > 0) {
                final prevLine = lines[i - 1].trimRight();
                // If prev line doesn't end with comma, we need to add one.
                // But we've already written it into buf — so we need to fix it.
                // Actually let's just reconstruct: the prev line is already in buf.
                // Simplest: insert the output param before ");"
              }
              buf.writeln(
                '    output: kDebugMode\n'
                '        ? MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()])\n'
                '        : ConsoleOutput(),',
              );
              buf.writeln(closingLine); // the ");' line
            } else if (closingTrimmed.endsWith(');')) {
              // Something like "    level: kDebugMode ? Level.trace : Level.warning,);"
              // or "    level: kDebugMode ? Level.trace : Level.warning,  );"
              // Replace ); with ,\n output param \n);
              final indent = closingLine.substring(
                0,
                closingLine.length - closingLine.trimLeft().length,
              );
              // Strip the ); from the end
              final withoutClose = closingTrimmed.substring(
                0,
                closingTrimmed.length - 2,
              );
              // Ensure trailing comma
              final paramPart = withoutClose.endsWith(',')
                  ? withoutClose
                  : '$withoutClose,';
              buf.writeln('$indent$paramPart');
              buf.writeln(
                '${indent}  output: kDebugMode\n'
                '${indent}      ? MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()])\n'
                '${indent}      : ConsoleOutput(),',
              );
              buf.writeln('$indent);');
            }
          } else {
            buf.writeln(lines[i]);
          }
        }
        // Remove last trailing newline added by writeln
        content = buf.toString();
        if (content.endsWith('\n')) {
          content = content.substring(0, content.length - 1);
        }
        modified = true;
      } else if (loggerStart != -1 && loggerEnd != -1 && hasOutputParam) {
        // Has output: already — try to add LayerXLogInterceptorOutput into it.
        // Replace standalone ConsoleOutput() with MultiOutput([...])
        if (content.contains(RegExp(r'output:\s*ConsoleOutput\(\)'))) {
          content = content.replaceFirst(
            RegExp(r'output:\s*ConsoleOutput\(\)'),
            'output: MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()])',
          );
          modified = true;
        } else if (content.contains('MultiOutput([') &&
            content.contains('ConsoleOutput()') &&
            !content.contains('LayerXLogInterceptorOutput')) {
          // Already a MultiOutput — just add our output after ConsoleOutput()
          content = content.replaceFirst(
            'ConsoleOutput()',
            'ConsoleOutput(), LayerXLogInterceptorOutput()',
          );
          modified = true;
        }
      }
    }

    // ── 5. Post-processing: fix any stray double-commas (safety net) ─────────
    content = content.replaceAll(RegExp(r',\s*,'), ',');

    if (modified) {
      final backupFile = File(
        '$projectRoot/lib/app/services/logger_service.dart.bak',
      );
      if (!backupFile.existsSync()) {
        backupFile.writeAsStringSync(loggerFile.readAsStringSync());
      }
      loggerFile.writeAsStringSync(content);
      CliPrinter.success(
        'logger_service.dart bound with LayerXLogInterceptorOutput (backup created).',
      );
    }

    if (!modified && !content.contains('LayerXLogInterceptorOutput')) {
      CliPrinter.warning(
        'Found logger_service.dart but could not auto-patch it.\n'
        '     Please add LayerXLogInterceptorOutput() to your Logger output manually.',
      );
    }

    return modified;
  }

  // ── HttpsCalls ────────────────────────────────────────────────────────────

  bool _patchHttpsCalls() {
    final httpFile = File('$projectRoot/lib/app/services/https_calls.dart');
    if (!httpFile.existsSync()) {
      CliPrinter.info('https_calls.dart not found — skipping.');
      return false;
    }

    var content = httpFile.readAsStringSync();
    bool modified = false;

    // ── 1. Remove old debug_logger / lx_http_interceptor imports ─────────────
    final oldImports = RegExp(
      r"import\s+'[^']*(?:debug_logger|lx_http_interceptor)[^']*';\n?",
    );
    if (content.contains(oldImports)) {
      content = content.replaceAll(oldImports, '');
      modified = true;
    }

    // ── 2. Ensure dart:convert is imported ────────────────────────────────────
    if (!content.contains("import 'dart:convert';")) {
      final asyncImport = "import 'dart:async';";
      if (content.contains(asyncImport)) {
        content = content.replaceFirst(
          asyncImport,
          "$asyncImport\nimport 'dart:convert';",
        );
      } else {
        content = "import 'dart:convert';\n$content";
      }
      modified = true;
    }

    // ── 3. Add debugger package import ────────────────────────────────────────
    final debuggerImport =
        "import 'package:layerx_debugger/layerx_debugger.dart';";
    if (!content.contains(debuggerImport)) {
      final httpImport = "import 'package:http/http.dart' as http;";
      if (content.contains(httpImport)) {
        content = content.replaceFirst(
          httpImport,
          '$httpImport\n$debuggerImport',
        );
      } else {
        content = '$debuggerImport\n$content';
      }
      modified = true;
    }

    // ── 4. Replace LxHttpInterceptor.record(..., response: r, ...) ───────────
    // The legacy call passes the full http.Response object. We must unpack it.
    //
    // Pattern:
    //   LxHttpInterceptor.record(
    //     endpoint: endpoint,
    //     method: method.name.toUpperCase(),
    //     response: response,
    //     requestBody: requestBodyStr,
    //     durationMs: stopwatch.elapsedMilliseconds,
    //   );
    final lxRecordPattern = RegExp(
      r'LxHttpInterceptor\.record\s*\(\s*'
      r'endpoint:\s*(\w+)\s*,\s*'
      r'method:\s*([^,]+),\s*'
      r'response:\s*(\w+)\s*,\s*'
      r'requestBody:\s*(\w+)\s*,\s*'
      r'durationMs:\s*([^,\)]+),?\s*'
      r'\)\s*;',
      dotAll: true,
    );

    if (content.contains(lxRecordPattern)) {
      content = content.replaceAllMapped(lxRecordPattern, (m) {
        final ep = m.group(1)!.trim();
        final met = m.group(2)!.trim();
        final resp = m.group(3)!.trim();
        final reqB = m.group(4)!.trim();
        final dur = m.group(5)!.trim();
        return 'LayerXNetworkLogger.record(\n'
            '              endpoint: $ep,\n'
            '              method: $met,\n'
            '              statusCode: $resp.statusCode,\n'
            '              responseBody: $resp.body,\n'
            '              requestBody: $reqB,\n'
            '              responseHeaders: $resp.headers,\n'
            '              durationMs: $dur,\n'
            '            );';
      });
      modified = true;
    }

    // ── 5. Fallback: generic LxHttpInterceptor.record with named args ─────────
    // Catch any remaining LxHttpInterceptor.record(...) calls that have
    // a `response:` named parameter (regardless of arg order).
    if (content.contains('LxHttpInterceptor.record')) {
      final genericPattern = RegExp(
        r'LxHttpInterceptor\.record\s*\((.*?)\)\s*;',
        dotAll: true,
      );
      content = content.replaceAllMapped(genericPattern, (m) {
        final args = m.group(1)!;
        // Extract named args
        String _extract(String key) {
          final r = RegExp('$key:\\s*([^,\\)]+)');
          return r.firstMatch(args)?.group(1)?.trim() ?? '?';
        }

        final ep = _extract('endpoint');
        final met = _extract('method');
        final resp = _extract('response');
        final reqB = _extract('requestBody');
        final dur = _extract('durationMs');
        if (resp == '?') return m.group(0)!; // can't parse — leave as-is
        return 'LayerXNetworkLogger.record(\n'
            '              endpoint: $ep,\n'
            '              method: $met,\n'
            '              statusCode: $resp.statusCode,\n'
            '              responseBody: $resp.body,\n'
            '              requestBody: $reqB,\n'
            '              responseHeaders: $resp.headers,\n'
            '              durationMs: $dur,\n'
            '            );';
      });
      modified = true;
    }

    if (modified) {
      final backupFile = File(
        '$projectRoot/lib/app/services/https_calls.dart.bak',
      );
      if (!backupFile.existsSync()) {
        backupFile.writeAsStringSync(httpFile.readAsStringSync());
      }
      httpFile.writeAsStringSync(content);
      CliPrinter.success(
        'https_calls.dart bound with LayerXNetworkLogger (backup created).',
      );
    }

    if (!modified && !content.contains('LayerXNetworkLogger')) {
      CliPrinter.warning(
        'Found https_calls.dart but no legacy LxHttpInterceptor calls to replace.\n'
        '     To log HTTP requests, call LayerXNetworkLogger.record(...) inside your HTTP client methods.',
      );
    }

    return modified;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _cleanOldDebugLogger() {
    final oldDir = Directory('$projectRoot/lib/app/debug_logger');
    if (oldDir.existsSync()) {
      try {
        oldDir.deleteSync(recursive: true);
        CliPrinter.success(
          'Removed legacy lib/app/debug_logger directory.',
        );
      } catch (e) {
        CliPrinter.warning(
          'Failed to delete lib/app/debug_logger directory: $e',
        );
      }
    }
  }
}
