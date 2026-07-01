import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';

/// Renders LayerX console output: colored level lines and the boxed
/// (`┌─ │ └`) format used for HTTP request/response/error logs.
///
/// All ANSI coloring is gated by a `colors` flag so it can be disabled in
/// release/production where escape codes would be noise.
class LayerXConsolePrinter {
  LayerXConsolePrinter._();

  static const String _reset = '\x1B[0m';
  static const int _boxWidth = 60;

  /// The ANSI foreground escape code for a [level], honoring the spec palette:
  /// blue=info, green=success, yellow=warning, red=error, grey=debug/verbose.
  static String ansiCode(LayerXLogLevel level) {
    switch (level) {
      case LayerXLogLevel.verbose:
      case LayerXLogLevel.debug:
        return '\x1B[90m';
      case LayerXLogLevel.info:
        return '\x1B[34m';
      case LayerXLogLevel.success:
        return '\x1B[32m';
      case LayerXLogLevel.warning:
        return '\x1B[33m';
      case LayerXLogLevel.error:
        return '\x1B[31m';
      case LayerXLogLevel.fatal:
        return '\x1B[91m';
    }
  }

  /// Formats a single colored log line, e.g. `✅ [10:42:07] SUCCESS Saved`.
  static String formatLine(
    LayerXLogLevel level,
    String message, {
    required bool colors,
  }) {
    final line = '${level.emoji} [${_time()}] ${level.label} $message';
    return colors ? '${ansiCode(level)}$line$_reset' : line;
  }

  /// Builds the boxed block for the given [title] and body [lines].
  ///
  /// Each returned string is one console line. When [colors] is true the whole
  /// box is tinted with the [level] color.
  static List<String> box({
    required String title,
    required List<String> lines,
    LayerXLogLevel level = LayerXLogLevel.info,
    required bool colors,
  }) {
    final rule = '─' * _boxWidth;
    final raw = <String>[
      '┌$rule',
      '│ $title',
      ...lines.expand(_wrap).map((l) => '│ $l'),
      '└$rule',
    ];
    if (!colors) return raw;
    final code = ansiCode(level);
    return raw.map((l) => '$code$l$_reset').toList();
  }

  /// Prints [formatLine] to the console via [debugPrint].
  static void printLine(
    LayerXLogLevel level,
    String message, {
    required bool colors,
  }) {
    LayerXConsoleCapture.guard(
        () => debugPrint(formatLine(level, message, colors: colors)));
  }

  /// Prints a [box] to the console via [debugPrint].
  static void printBox({
    required String title,
    required List<String> lines,
    LayerXLogLevel level = LayerXLogLevel.info,
    required bool colors,
  }) {
    for (final line in box(
      title: title,
      lines: lines,
      level: level,
      colors: colors,
    )) {
      LayerXConsoleCapture.guard(() => debugPrint(line));
    }
  }

  /// Splits a long string into chunks that fit inside the box.
  static Iterable<String> _wrap(String value) sync* {
    for (final raw in value.split('\n')) {
      if (raw.length <= _boxWidth) {
        yield raw;
      } else {
        for (var i = 0; i < raw.length; i += _boxWidth) {
          yield raw.substring(
            i,
            i + _boxWidth > raw.length ? raw.length : i + _boxWidth,
          );
        }
      }
    }
  }

  static String _time() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }
}
