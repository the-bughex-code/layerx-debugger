import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// The runtime environment LayerX is operating in.
///
/// The environment controls how chatty and how colorful LayerX is, and whether
/// the in-app viewer is available.
enum LayerXEnvironment {
  /// Local development: everything is logged, colorized, and the viewer is on.
  dev,

  /// Pre-production: informational logs and above, viewer on.
  staging,

  /// Production: warnings and above only, no colors, viewer off.
  prod;

  /// The lowest [LayerXLogLevel] that should reach the console in this
  /// environment.
  LayerXLogLevel get minimumLevel {
    switch (this) {
      case LayerXEnvironment.dev:
        return LayerXLogLevel.verbose;
      case LayerXEnvironment.staging:
        return LayerXLogLevel.info;
      case LayerXEnvironment.prod:
        return LayerXLogLevel.warning;
    }
  }

  /// Whether ANSI colors should be used in console output by default.
  bool get useColors => this != LayerXEnvironment.prod;

  /// Whether the in-app log viewer should be available by default.
  bool get viewerEnabled => this != LayerXEnvironment.prod;
}
