import 'package:flutter/material.dart';

/// The functional section a log entry belongs to.
///
/// A category is orthogonal to [LayerXLogLevel] (severity) and
/// [LayerXLogSource] (ownership): it groups entries into the sections shown in
/// the in-app viewer (Debug Console, UI Exceptions, Navigation, …).
enum LayerXLogCategory {
  /// General application logs (e.g. `debugPrint`/`print` output).
  app,

  /// Flutter framework-level errors reported via [FlutterError].
  framework,

  /// Rendering/widget-tree exceptions surfaced in the UI layer.
  uiException,

  /// Uncaught Dart exceptions and errors.
  dartException,

  /// Raw network/transport activity.
  network,

  /// API request/response captures.
  api,

  /// Route pushes, pops and other navigation events.
  navigation,

  /// Widget/app lifecycle events.
  lifecycle,

  /// Performance metrics and profiling entries.
  performance,

  /// Fatal crash reports.
  crash,

  /// Entries surfaced from the in-app debug console.
  debugConsole,

  /// System-level or platform log entries.
  system;

  /// A human-readable label shown in the viewer.
  String get label {
    switch (this) {
      case LayerXLogCategory.app:
        return 'App Logs';
      case LayerXLogCategory.framework:
        return 'Flutter Framework';
      case LayerXLogCategory.uiException:
        return 'UI Exceptions';
      case LayerXLogCategory.dartException:
        return 'Dart Exceptions';
      case LayerXLogCategory.network:
        return 'Network';
      case LayerXLogCategory.api:
        return 'API';
      case LayerXLogCategory.navigation:
        return 'Navigation';
      case LayerXLogCategory.lifecycle:
        return 'Lifecycle';
      case LayerXLogCategory.performance:
        return 'Performance';
      case LayerXLogCategory.crash:
        return 'Crash Logs';
      case LayerXLogCategory.debugConsole:
        return 'Debug Console';
      case LayerXLogCategory.system:
        return 'System Logs';
    }
  }

  /// The accent color used for this category in the viewer.
  Color get color {
    switch (this) {
      case LayerXLogCategory.app:
        return const Color(0xFF39D353);
      case LayerXLogCategory.framework:
        return const Color(0xFF38BDF8);
      case LayerXLogCategory.uiException:
        return const Color(0xFFFF5C57);
      case LayerXLogCategory.dartException:
        return const Color(0xFFFF9F45);
      case LayerXLogCategory.network:
        return const Color(0xFF22D3EE);
      case LayerXLogCategory.api:
        return const Color(0xFF38BDF8);
      case LayerXLogCategory.navigation:
        return const Color(0xFFA78BFA);
      case LayerXLogCategory.lifecycle:
        return const Color(0xFF3FE06B);
      case LayerXLogCategory.performance:
        return const Color(0xFFE3B341);
      case LayerXLogCategory.crash:
        return const Color(0xFFB71C1C);
      case LayerXLogCategory.debugConsole:
        return const Color(0xFF6FA982);
      case LayerXLogCategory.system:
        return const Color(0xFF9E9E9E);
    }
  }

  /// A Material icon used as this category's glyph in the viewer.
  IconData get icon {
    switch (this) {
      case LayerXLogCategory.app:
        return Icons.code;
      case LayerXLogCategory.framework:
        return Icons.flutter_dash;
      case LayerXLogCategory.uiException:
        return Icons.widgets_outlined;
      case LayerXLogCategory.dartException:
        return Icons.bug_report_outlined;
      case LayerXLogCategory.network:
        return Icons.wifi_tethering;
      case LayerXLogCategory.api:
        return Icons.swap_vert;
      case LayerXLogCategory.navigation:
        return Icons.alt_route;
      case LayerXLogCategory.lifecycle:
        return Icons.autorenew;
      case LayerXLogCategory.performance:
        return Icons.speed;
      case LayerXLogCategory.crash:
        return Icons.dangerous_outlined;
      case LayerXLogCategory.debugConsole:
        return Icons.terminal;
      case LayerXLogCategory.system:
        return Icons.settings_suggest_outlined;
    }
  }
}
