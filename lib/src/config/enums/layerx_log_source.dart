import 'package:flutter/material.dart';

/// The most likely origin of a log entry.
///
/// LayerX classifies each entry so that the in-app viewer can show, at a
/// glance, who most likely owns an issue (the app, the backend or the network).
enum LayerXLogSource {
  /// An issue inside the Flutter/Dart application code.
  app,

  /// A server-side failure, typically a `5xx` status code.
  server,

  /// A backend/business-logic rejection, typically a `4xx` status code.
  backend,

  /// A connectivity or transport-layer problem.
  network,

  /// The source could not be determined.
  unknown;

  /// The accent color used for this source in the in-app viewer.
  ///
  /// UX P4 (§4.2 semantic AA remap): sources render as `LxKit.pill` chips —
  /// the label is painted in this color on its own 14%-alpha tint over surface.
  /// Each value therefore clears WCAG-AA (≥ 4.5:1) as label-on-own-tint, pinned
  /// by `test/config/theme_contrast_test.dart` (the old mid-tone hues failed).
  Color get color {
    switch (this) {
      case LayerXLogSource.app:
        return const Color(0xFFB79CFF); // bright violet — app (5.97:1)
      case LayerXLogSource.server:
        return const Color(0xFFFF6B6B); // accentRed — danger (5.18:1)
      case LayerXLogSource.backend:
        return const Color(0xFFF4B740); // accentAmber — warning (7.32:1)
      case LayerXLogSource.network:
        return const Color(0xFF5AA9FF); // accentBlue — info (5.62:1)
      case LayerXLogSource.unknown:
        return const Color(0xFFAEB8C4); // textSecondary — neutral (6.61:1)
    }
  }

  /// A human-readable, emoji-prefixed label for this source.
  String get label {
    switch (this) {
      case LayerXLogSource.app:
        return '📱 App Issue';
      case LayerXLogSource.server:
        return '🖥 Server Error';
      case LayerXLogSource.backend:
        return '⚙️ Backend';
      case LayerXLogSource.network:
        return '🌐 Network';
      case LayerXLogSource.unknown:
        return '❓ Unknown';
    }
  }
}
