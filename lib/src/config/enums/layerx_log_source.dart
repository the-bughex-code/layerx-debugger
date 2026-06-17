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
  Color get color {
    switch (this) {
      case LayerXLogSource.app:
        return const Color(0xFF7E57C2);
      case LayerXLogSource.server:
        return const Color(0xFFEF5350);
      case LayerXLogSource.backend:
        return const Color(0xFFFF7043);
      case LayerXLogSource.network:
        return const Color(0xFF26C6DA);
      case LayerXLogSource.unknown:
        return const Color(0xFFBDBDBD);
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
