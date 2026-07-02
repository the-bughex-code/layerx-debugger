import 'package:flutter/foundation.dart';

import 'package:layerx_debugger/src/config/enums/layerx_environment.dart';

/// Where the edge-swipe gesture that opens the in-app viewer lives.
enum LayerXEdgeZone {
  /// Swipe in from the left edge.
  left,

  /// Swipe in from the right edge.
  right,

  /// Swipe up from the bottom edge.
  bottom,
}

/// Signature for the optional crash-forwarding callback.
///
/// LayerX invokes this for every captured error so apps can forward it to a
/// crash reporter such as Firebase Crashlytics or Sentry. [fatal] is `true` for
/// uncaught zone/platform errors.
typedef LayerXCrashCallback = void Function(
  Object error,
  StackTrace stackTrace,
  bool fatal,
);

/// Immutable configuration for LayerX, passed to
/// [LayerXDebugger.initialize].
///
/// Every feature can be toggled independently. Defaults are tuned for local
/// development: all features on, colors on, the in-app viewer enabled.
class LayerXDebugConfig {
  /// Whether HTTP request/response/error logging is captured.
  final bool enableApiLogs;

  /// Whether route changes are logged.
  final bool enableRouteLogs;

  /// Whether uncaught errors and Flutter framework errors are captured.
  final bool enableCrashLogs;

  /// Whether GetX controller/service lifecycle events are logged.
  final bool enableGetXLogs;

  /// Whether [LayerXProfiler] measurements are logged.
  final bool enablePerformanceLogs;

  /// Whether [LayerXDebugWidget] rebuild counts are logged.
  final bool enableWidgetLogs;

  /// Extra keys (case-insensitive) whose values are masked in logged payloads,
  /// in addition to the built-in `password`, `token`, `authorization`,
  /// `apiKey` and `secret`.
  final List<String> maskKeys;

  /// The explicitly-set environment, or null to auto-select by build mode.
  final LayerXEnvironment? _environment;

  /// The active environment, controlling verbosity, colors and the viewer.
  ///
  /// When not set explicitly it auto-selects by build mode: [LayerXEnvironment.prod]
  /// in release builds (viewer/FAB off, warnings+ only) and [LayerXEnvironment.dev]
  /// otherwise. This means the debugger is debug/profile-only by default and can
  /// never leak into a production release unless you opt in.
  LayerXEnvironment get environment => resolveEnvironment(_environment);

  /// Resolves the active environment from an [explicit] value (if any) and the
  /// build mode. Exposed for testing; defaults [isRelease] to [kReleaseMode].
  static LayerXEnvironment resolveEnvironment(
    LayerXEnvironment? explicit, {
    bool isRelease = kReleaseMode,
  }) =>
      explicit ??
      (isRelease ? LayerXEnvironment.prod : LayerXEnvironment.dev);

  /// A human-readable application name shown in the viewer.
  final String appName;

  /// The app's package name (e.g. `my_app`) used to attribute log entries to
  /// the originating screen/method via stack-trace parsing. Optional.
  final String? packageName;

  /// Whether the draggable floating debug button is shown.
  final bool enableFloatingButton;

  /// Whether the edge-swipe gesture to open the viewer is enabled.
  final bool enableEdgeSwipe;

  /// Whether the in-viewer settings widget is shown.
  final bool enableSettingsWidget;

  /// Which screen edge hosts the open-viewer swipe gesture.
  final LayerXEdgeZone edgeSwipeZone;

  /// Forces ANSI colors on/off in the console. When `null`, the
  /// [environment]'s default is used.
  final bool? useColors;

  /// The maximum number of entries kept in the in-memory store.
  final int maxStoredLogs;

  /// Whether [LayerXDebugger.initialize] should auto-register the LayerX GetX
  /// services (logger, debug, crash, network, performance, route).
  final bool autoInject;

  /// Explicitly declares whether the host app uses LayerX architecture.
  ///
  /// When `null` (the default), LayerX assumes it does — the package is built
  /// for LayerX apps. Set it to `false` in a non-LayerX app to skip all
  /// injection and only print guidance.
  final bool? isLayerXArchitecture;

  /// Optional callback invoked for every captured crash/error so it can be
  /// forwarded to an external reporter. See [LayerXCrashCallback].
  final LayerXCrashCallback? onCrash;

  /// Creates a configuration. All parameters have development-friendly
  /// defaults, so `const LayerXDebugConfig()` is a sensible starting point.
  ///
  /// Leave [environment] unset to auto-select by build mode (prod in release,
  /// dev otherwise) — see [environment].
  const LayerXDebugConfig({
    this.enableApiLogs = true,
    this.enableRouteLogs = true,
    this.enableCrashLogs = true,
    this.enableGetXLogs = true,
    this.enablePerformanceLogs = true,
    this.enableWidgetLogs = true,
    this.maskKeys = const [],
    LayerXEnvironment? environment,
    this.appName = 'LayerX App',
    this.packageName,
    this.enableFloatingButton = true,
    this.enableEdgeSwipe = true,
    this.enableSettingsWidget = true,
    this.edgeSwipeZone = LayerXEdgeZone.right,
    this.useColors,
    this.maxStoredLogs = 500,
    this.autoInject = true,
    this.isLayerXArchitecture,
    this.onCrash,
  }) : _environment = environment;

  /// Whether ANSI colors should be emitted, honoring [useColors] then the
  /// [environment] default.
  bool get resolvedUseColors => useColors ?? environment.useColors;

  /// Whether the in-app viewer should be shown, combining the environment with
  /// the floating-button / edge-swipe toggles.
  bool get viewerEnabled =>
      environment.viewerEnabled && (enableFloatingButton || enableEdgeSwipe);
}
