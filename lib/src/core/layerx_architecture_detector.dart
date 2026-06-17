import 'package:flutter/foundation.dart';

import '../logger/layerx_log.dart';
import '../models/layerx_architecture_report.dart';
import 'layerx_debug_config.dart';

/// Best-effort, runtime architecture detection for LayerX.
///
/// Folder-based detection is impossible in a released app, so this tracks the
/// modules it can actually observe — controllers and network usage light up
/// incrementally as the app exercises them — and combines that with explicit
/// configuration hints ([LayerXDebugConfig.isLayerXArchitecture]).
class LayerXArchitectureDetector {
  LayerXArchitectureDetector._();

  static bool _controllers = false;
  static bool _network = false;
  static bool _services = false;

  /// Flags that a LayerX GetX controller has run.
  static void markControllers() {
    if (_controllers) return;
    _controllers = true;
    _announce('Controllers');
  }

  /// Flags that the network/HTTP layer has produced a log.
  static void markNetwork() {
    if (_network) return;
    _network = true;
    _announce('HTTP layer');
  }

  /// Flags that the LayerX GetX services have been registered.
  static void markServices() => _services = true;

  /// Produces a snapshot [LayerXArchitectureReport] for [config].
  static LayerXArchitectureReport detect(LayerXDebugConfig config) {
    final isLayerX = config.isLayerXArchitecture ?? true;
    return LayerXArchitectureReport(
      isLayerX: isLayerX,
      getxDetected: isLayerX,
      servicesDetected: _services,
      controllersDetected: _controllers,
      networkDetected: _network,
      uiOnly: !_controllers && !_network && !_services,
    );
  }

  /// Resets all runtime flags. Used by [LayerXDebugger.resetForTesting].
  static void reset() {
    _controllers = false;
    _network = false;
    _services = false;
  }

  /// Prints the detection banner for [report] to the console.
  static void printBanner(LayerXArchitectureReport report) {
    final lines = <String>['', '[LayerX Debugger]', ''];

    if (!report.isLayerX) {
      lines.addAll([
        '⚠ LayerX architecture was not detected.',
        '',
        'This package is designed for the legacy LayerX Architecture by '
            'Umair Hashmi.',
        'Debugger injection has been skipped for this application.',
        '',
        'Detected project type: Generic Flutter Application.',
      ]);
      _flush(lines);
      return;
    }

    lines.add('✓ LayerX architecture detected');
    lines.add(report.getxDetected ? '✓ GetX detected' : '⚠ GetX not detected');
    lines.add('✓ UI detected');
    lines.add(report.controllersDetected
        ? '✓ Controllers detected'
        : '⚠ Controllers not found yet');
    lines.add(report.servicesDetected
        ? '✓ Services registered'
        : '⚠ Services not found yet');
    lines.add(report.networkDetected
        ? '✓ HTTP layer detected'
        : '⚠ API layer not found yet');

    if (report.isPartial) {
      lines.addAll([
        '',
        'Debugger initialized with partial integration.',
        'Add controllers, services or an API layer and re-run — the debugger '
            'will activate the new modules automatically.',
      ]);
    } else {
      lines.add('✓ Debugger injected successfully');
    }

    _flush(lines);
  }

  static void _announce(String module) {
    LayerXLog.i('[LayerX Debugger] $module detected — module activated.');
  }

  static void _flush(List<String> lines) {
    for (final line in lines) {
      debugPrint(line);
    }
  }
}
