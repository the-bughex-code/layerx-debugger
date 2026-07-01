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
/// See the README for HTTP capture (and the optional Dio recipe), route
/// observers, GetX integration, crash handling, performance profiling and the
/// in-app log viewer.
library;

// ── Models ───────────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/mvvm/model/layerx_architecture_report.dart';
export 'package:layerx_debugger/src/mvvm/model/layerx_journey_step.dart';
export 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
export 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
export 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
export 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
export 'package:layerx_debugger/src/mvvm/model/layerx_schema_change.dart';

// ── Utilities & engines ──────────────────────────────────────────────────────
export 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';
export 'package:layerx_debugger/src/repository/layerx_log_store.dart';

// ── Core ─────────────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/core/bindings/layerx_bindings.dart';
export 'package:layerx_debugger/src/core/layerx_architecture_detector.dart';
export 'package:layerx_debugger/src/config/layerx_debug_config.dart';
export 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
export 'package:layerx_debugger/src/config/enums/layerx_environment.dart';
export 'package:layerx_debugger/src/core/profiler/layerx_profiler.dart';

// ── Services (GetX) ──────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/services/crash/layerx_crash_service.dart';
export 'package:layerx_debugger/src/services/debug/layerx_debug_service.dart';
export 'package:layerx_debugger/src/services/logger/layerx_logger_service.dart';
export 'package:layerx_debugger/src/services/network/layerx_network_service.dart';
export 'package:layerx_debugger/src/services/performance/layerx_performance_service.dart';
export 'package:layerx_debugger/src/services/performance/layerx_frame_monitor.dart';
export 'package:layerx_debugger/src/services/route/layerx_route_service.dart';

// ── Widgets ──────────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/widgets/layerx_debug_overlay.dart';
export 'package:layerx_debugger/src/widgets/layerx_debug_widget.dart';
export 'package:layerx_debugger/src/widgets/parts/lx_debug_settings_button.dart'
    show LayerXDebugSettingsButton;

// ── Logging ──────────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/services/logger/layerx_log.dart';

// ── Crash handling ───────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/services/crash/layerx_crash_handler.dart';

// ── Extensions ───────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/config/extensions/layerx_log_extensions.dart';

// ── GetX integration ─────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/mvvm/view_model/layerx_controller.dart';
export 'package:layerx_debugger/src/core/mixins/layerx_debug_mixin.dart';
export 'package:layerx_debugger/src/mvvm/view_model/layerx_service.dart';

// ── Navigation ───────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/services/route/layerx_route_middleware.dart';
export 'package:layerx_debugger/src/services/route/layerx_route_observer.dart';

// ── Network ──────────────────────────────────────────────────────────────────
export 'package:layerx_debugger/src/services/network/layerx_http.dart';
export 'package:layerx_debugger/src/services/network/layerx_http_client.dart';
export 'package:layerx_debugger/src/config/utils/layerx_masker.dart';
export 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';
export 'package:layerx_debugger/src/services/logger/layerx_log_interceptor_output.dart';
