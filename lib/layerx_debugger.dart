/// LayerX Debugger — a drop-in debugger and logger for Flutter and GetX.
///
/// Import this single library to access the entire public API:
///
/// ```dart
/// import 'package:layerx_debugger/layerx_debugger.dart';
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LayerXDebugger.initialize();
///   runApp(const MyApp());
/// }
/// ```
///
/// See the README for full setup of the Dio interceptor, route observers,
/// GetX integration, crash handling, performance profiling and the in-app
/// log viewer.
library;

// ── Models ───────────────────────────────────────────────────────────────────
export 'src/models/layerx_architecture_report.dart';
export 'src/models/layerx_journey_step.dart';
export 'src/models/layerx_log_entry.dart';
export 'src/models/layerx_log_level.dart';
export 'src/models/layerx_log_source.dart';
export 'src/models/layerx_schema_change.dart';

// ── Utilities & engines ──────────────────────────────────────────────────────
export 'src/utils/layerx_blame_engine.dart';
export 'src/utils/layerx_log_store.dart';

// ── Core ─────────────────────────────────────────────────────────────────────
export 'src/core/bindings/layerx_bindings.dart';
export 'src/core/layerx_architecture_detector.dart';
export 'src/core/layerx_debug_config.dart';
export 'src/core/layerx_debugger.dart';
export 'src/core/layerx_environment.dart';
export 'src/core/layerx_profiler.dart';

// ── Services (GetX) ──────────────────────────────────────────────────────────
export 'src/services/layerx_crash_service.dart';
export 'src/services/layerx_debug_service.dart';
export 'src/services/layerx_logger_service.dart';
export 'src/services/layerx_network_service.dart';
export 'src/services/layerx_performance_service.dart';
export 'src/services/layerx_route_service.dart';

// ── Widgets ──────────────────────────────────────────────────────────────────
export 'src/widgets/layerx_debug_overlay.dart';
export 'src/widgets/layerx_debug_widget.dart';
export 'src/widgets/parts/lx_debug_settings_button.dart'
    show LayerXDebugSettingsButton;

// ── Logging ──────────────────────────────────────────────────────────────────
export 'src/logger/layerx_log.dart';

// ── Crash handling ───────────────────────────────────────────────────────────
export 'src/crash/layerx_crash_handler.dart';

// ── Extensions ───────────────────────────────────────────────────────────────
export 'src/extensions/layerx_log_extensions.dart';

// ── GetX integration ─────────────────────────────────────────────────────────
export 'src/getx/layerx_controller.dart';
export 'src/getx/layerx_debug_mixin.dart';
export 'src/getx/layerx_service.dart';

// ── Navigation ───────────────────────────────────────────────────────────────
export 'src/navigation/layerx_route_middleware.dart';
export 'src/navigation/layerx_route_observer.dart';

// ── Network ──────────────────────────────────────────────────────────────────
export 'src/network/layerx_http.dart';
export 'src/network/layerx_masker.dart';
export 'src/network/layerx_network_logger.dart';
