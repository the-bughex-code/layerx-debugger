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
  ///
  /// UX P4 (§4.2 semantic AA remap): categories render as `LxTheme.pill` chips
  /// (label painted in this color on its own 14%-alpha tint over surface), so
  /// each value maps to the nearest `LxTheme` semantic family — except
  /// `navigation`, a bespoke bright violet `#B79CFF` with no theme token (§4
  /// retired purple; `accentPurple` now aliases `accentAmber`). Every value
  /// clears WCAG-AA (≥ 4.5:1) as label-on-own-tint — pinned by
  /// `test/config/theme_contrast_test.dart`. `crash` uses the danger red
  /// `#FF6B6B` rather than the darker `critical #FF3B3B`, which reads only
  /// 4.32:1 on its own tint (below the chip floor).
  Color get color {
    switch (this) {
      case LayerXLogCategory.app:
        return const Color(0xFF3DD68C); // accentGreen — app/success (7.06:1)
      case LayerXLogCategory.framework:
        return const Color(0xFF5AA9FF); // accentBlue — info (5.62:1)
      case LayerXLogCategory.uiException:
        return const Color(0xFFFF6B6B); // accentRed — danger (5.18:1)
      case LayerXLogCategory.dartException:
        return const Color(0xFFF4B740); // accentAmber — warning (7.32:1)
      case LayerXLogCategory.network:
        return const Color(0xFF5AA9FF); // accentBlue — info (5.62:1)
      case LayerXLogCategory.api:
        return const Color(0xFF5AA9FF); // accentBlue — info (5.62:1)
      case LayerXLogCategory.navigation:
        return const Color(0xFFB79CFF); // bright violet (5.97:1)
      case LayerXLogCategory.lifecycle:
        return const Color(0xFF3DD68C); // accentGreen — brand (7.06:1)
      case LayerXLogCategory.performance:
        return const Color(0xFFF4B740); // accentAmber — warning (7.32:1)
      case LayerXLogCategory.crash:
        return const Color(0xFFFF6B6B); // accentRed — danger (5.18:1)
      case LayerXLogCategory.debugConsole:
        return const Color(0xFF8B95A2); // textTertiary — neutral (4.68:1)
      case LayerXLogCategory.system:
        return const Color(0xFFAEB8C4); // textSecondary — neutral (6.61:1)
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
