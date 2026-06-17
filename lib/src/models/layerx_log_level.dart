import 'package:flutter/material.dart';

/// Severity levels recorded by LayerX, ordered from least to most severe.
///
/// The [success] level is unique to LayerX and is rendered in green to mark a
/// successful operation (for example a `2xx` API response).
enum LayerXLogLevel {
  /// Highly detailed tracing output, usually disabled outside deep debugging.
  verbose,

  /// Diagnostic information useful while developing.
  debug,

  /// General informational messages.
  info,

  /// A successful operation, rendered in green.
  success,

  /// Something unexpected that is not (yet) an error.
  warning,

  /// A recoverable error.
  error,

  /// A fatal, typically unrecoverable error.
  fatal;

  /// The accent color used for this level in the console and the in-app viewer.
  Color get color {
    switch (this) {
      case LayerXLogLevel.verbose:
        return const Color(0xFF9E9E9E);
      case LayerXLogLevel.debug:
        return const Color(0xFF607D8B);
      case LayerXLogLevel.info:
        return const Color(0xFF42A5F5);
      case LayerXLogLevel.success:
        return const Color(0xFF43A047);
      case LayerXLogLevel.warning:
        return const Color(0xFFFFA726);
      case LayerXLogLevel.error:
        return const Color(0xFFEF5350);
      case LayerXLogLevel.fatal:
        return const Color(0xFFB71C1C);
    }
  }

  /// An optional tinted background color used for the level's row in the viewer.
  ///
  /// Returns `null` for levels that should use the default surface color.
  Color? get backgroundColor {
    switch (this) {
      case LayerXLogLevel.success:
        return const Color(0xFFF1F8F2);
      case LayerXLogLevel.warning:
        return const Color(0xFFFFFBF0);
      case LayerXLogLevel.error:
        return const Color(0xFFFFF5F5);
      case LayerXLogLevel.fatal:
        return const Color(0xFFFFF0F0);
      default:
        return null;
    }
  }

  /// The uppercase label shown in the UI, e.g. `ERROR`.
  String get label => name.toUpperCase();

  /// A short emoji marker used as a visual prefix for this level.
  String get emoji {
    switch (this) {
      case LayerXLogLevel.verbose:
        return '📓';
      case LayerXLogLevel.debug:
        return '🌀';
      case LayerXLogLevel.info:
        return '🩵';
      case LayerXLogLevel.success:
        return '✅';
      case LayerXLogLevel.warning:
        return '⚡';
      case LayerXLogLevel.error:
        return '⛔';
      case LayerXLogLevel.fatal:
        return '🔥';
    }
  }
}
