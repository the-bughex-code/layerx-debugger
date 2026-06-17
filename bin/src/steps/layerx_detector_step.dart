// ignore_for_file: avoid_print
import 'dart:io';

import '../utils/cli_printer.dart';

/// Result of scanning the project for LayerX architecture patterns.
class LayerXDetectionResult {
  final bool isLayerXProject;
  final List<String> foundSignals;

  const LayerXDetectionResult({
    required this.isLayerXProject,
    required this.foundSignals,
  });
}

/// Scans the project's lib/ folder for LayerX architecture signals:
///   - Classes extending LayerXController
///   - Classes extending LayerXService
///   - Usage of LayerXDebugMixin
///   - GetMaterialApp / GetPage (GetX routing)
class LayerXDetectorStep {
  final String projectRoot;

  LayerXDetectorStep(this.projectRoot);

  static const _signals = {
    'LayerXController': r'\bextends\s+LayerXController\b',
    'LayerXService': r'\bextends\s+LayerXService\b',
    'LayerXDebugMixin': r'\bwith\s+LayerXDebugMixin\b',
    'GetMaterialApp': r'\bGetMaterialApp\b',
    'GetPage routes': r'\bGetPage\b',
  };

  LayerXDetectionResult run() {
    CliPrinter.step('Scanning for LayerX architecture patterns ...');

    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      CliPrinter.warning('lib/ not found — skipping architecture scan.');
      return const LayerXDetectionResult(
        isLayerXProject: false,
        foundSignals: [],
      );
    }

    // Collect all Dart source under lib/.
    final allSource = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final found = <String>[];
    for (final entry in _signals.entries) {
      if (RegExp(entry.value).hasMatch(allSource)) {
        found.add(entry.key);
      }
    }

    // LayerX confirmed only if at least one of the core class patterns found.
    final isLayerX =
        found.contains('LayerXController') || found.contains('LayerXService');

    return LayerXDetectionResult(isLayerXProject: isLayerX, foundSignals: found);
  }

  /// Prints result and returns true to continue setup, false to abort.
  bool printAndDecide(LayerXDetectionResult result) {
    if (result.foundSignals.isNotEmpty) {
      for (final s in result.foundSignals) {
        CliPrinter.success('LayerX signal found → $s');
      }
    }

    if (result.isLayerXProject) {
      CliPrinter.success('LayerX architecture confirmed ✓');
      return true;
    }

    // ── NOT a LayerX project — show clear message and abort ──────────────────
    const yellow = '\x1B[33m';
    const bold = '\x1B[1m';
    const cyan = '\x1B[36m';
    const dim = '\x1B[2m';
    const underline = '\x1B[4m';
    const reset = '\x1B[0m';

    print('');
    print(
      '$bold$yellow'
      '  ╔═══════════════════════════════════════════════════════════╗\n'
      '  ║  ⚠️   Your app does not follow LayerX Architecture  ⚠️   ║\n'
      '  ╚═══════════════════════════════════════════════════════════╝'
      '$reset',
    );
    print('');
    print(
      '$bold  layerx_debugger is built for the LayerX Architecture pattern.$reset',
    );
    print(
      '$dim  No LayerXController or LayerXService was detected in lib/.$reset',
    );
    print('');
    CliPrinter.divider();
    print('');
    print('$bold  👉  Please migrate to LayerX Architecture first:$reset');
    print('');
    print(
      '  $cyan 1.$reset  Add $bold layerx_generator$reset to your dev_dependencies:',
    );
    print('');
    print(
      '$dim'
      '         dev_dependencies:\n'
      '           layerx_generator: ^2.0.2\n'
      '$reset',
    );
    print(
      '  $cyan 2.$reset  pub.dev → '
      '$underline${cyan}https://pub.dev/packages/layerx_generator$reset',
    );
    print('');
    print(
      '  $cyan 3.$reset  Generate your controllers & services using the generator,',
    );
    print('         then re-run:');
    print('');
    print('$dim         dart run layerx_debugger:setup$reset');
    print('');
    CliPrinter.divider();
    print('');
    CliPrinter.info(
      'Setup aborted. Convert your app to LayerX Architecture first, then retry.',
    );
    print('');

    return false;
  }
}
