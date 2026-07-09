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
  ///
  /// UX P4 (§4.2 semantic AA remap): every level maps to the shared `LxTheme`
  /// semantic palette — bright-on-dark variants that clear the WCAG-AA gate
  /// (`test/config/theme_contrast_test.dart`). Levels color the row rail and
  /// level icon (decorative, ≥ 3.0:1 on surface); `error`/`fatal` additionally
  /// drive title text, so they clear the full body floor (≥ 4.5:1 on surface).
  Color get color {
    switch (this) {
      case LayerXLogLevel.verbose:
        return const Color(0xFF8B95A2); // textTertiary — muted neutral
      case LayerXLogLevel.debug:
        return const Color(0xFFAEB8C4); // textSecondary — neutral
      case LayerXLogLevel.info:
        return const Color(0xFF5AA9FF); // accentBlue — info
      case LayerXLogLevel.success:
        return const Color(0xFF3DD68C); // accentGreen — brand/success
      case LayerXLogLevel.warning:
        return const Color(0xFFF4B740); // accentAmber — warning
      case LayerXLogLevel.error:
        return const Color(0xFFFF6B6B); // accentRed — danger (6.30:1)
      case LayerXLogLevel.fatal:
        return const Color(0xFFFF3B3B); // critical — crash/fatal (4.94:1)
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
