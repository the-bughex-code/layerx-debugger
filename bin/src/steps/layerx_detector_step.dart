// ignore_for_file: avoid_print
import 'dart:io';

import '../utils/cli_printer.dart';

/// Result of scanning the project for LayerX folder structure.
class LayerXDetectionResult {
  final bool isLayerXProject;
  final List<String> foundFolders;
  final List<String> missingRequired;

  const LayerXDetectionResult({
    required this.isLayerXProject,
    required this.foundFolders,
    required this.missingRequired,
  });
}

/// Detects LayerX Architecture by checking folder structure under lib/.
///
/// LayerX standard layout:
///   lib/
///     app/                ← required wrapper
///       mvvm/             ← REQUIRED (views, view_models, models)
///       services/         ← REQUIRED
///       config/           ← optional
///       repository/       ← optional
///       widgets/          ← optional
///       customWidgets/    ← optional
///   main.dart
///
/// Detection passes if lib/app/ exists AND at least one of
/// the REQUIRED folders (mvvm, services) is present inside it.
class LayerXDetectorStep {
  final String projectRoot;

  LayerXDetectorStep(this.projectRoot);

  // Must have at least one of these to be considered LayerX.
  static const _requiredFolders = ['mvvm'];

  // These are recognised but optional — shown as ✓ if found.
  static const _optionalFolders = [
    'services',
    'config',
    'repository',
    'widgets',
    'customWidgets',
  ];

  LayerXDetectionResult run() {
    CliPrinter.step('Scanning folder structure for LayerX Architecture ...');

    final appDir = Directory('$projectRoot/lib/app');
    final found = <String>[];
    final missingRequired = <String>[];

    if (!appDir.existsSync()) {
      // No lib/app/ at all — definitely not LayerX.
      return LayerXDetectionResult(
        isLayerXProject: false,
        foundFolders: [],
        missingRequired: _requiredFolders,
      );
    }

    // Check required folders.
    for (final name in _requiredFolders) {
      if (Directory('${appDir.path}/$name').existsSync()) {
        found.add(name);
      } else {
        missingRequired.add(name);
      }
    }

    // Check optional folders (just for display).
    for (final name in _optionalFolders) {
      if (Directory('${appDir.path}/$name').existsSync()) {
        found.add(name);
      }
    }

    // LayerX confirmed if lib/app/ exists + at least one required folder.
    final isLayerX =
        appDir.existsSync() && missingRequired.length < _requiredFolders.length;

    return LayerXDetectionResult(
      isLayerXProject: isLayerX,
      foundFolders: found,
      missingRequired: missingRequired,
    );
  }

  /// Prints the detection result and returns true to continue, false to abort.
  bool printAndDecide(LayerXDetectionResult result) {
    const green = '\x1B[32m';
    const yellow = '\x1B[33m';
    const cyan = '\x1B[36m';
    const bold = '\x1B[1m';
    const dim = '\x1B[2m';
    const underline = '\x1B[4m';
    const reset = '\x1B[0m';

    if (result.foundFolders.isNotEmpty) {
      CliPrinter.success('lib/app/ found ✓');
      for (final f in result.foundFolders) {
        print('$green    ✓  lib/app/$f/$reset');
      }
    }

    if (result.isLayerXProject) {
      CliPrinter.success('LayerX folder structure confirmed ✓');
      return true;
    }

    // ── NOT a LayerX project ─────────────────────────────────────────────────
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

    if (!Directory('$projectRoot/lib/app').existsSync()) {
      print('$dim  lib/app/ folder not found.$reset');
    } else {
      print(
        '$dim  lib/app/ found but missing required sub-folder: '
        'app/mvvm/$reset',
      );
    }

    print('');
    print(
      '$bold  Expected LayerX folder structure:$reset\n'
      '$dim'
      '    lib/\n'
      '      app/\n'
      '        mvvm/           ← required\n'
      '        services/       ← optional\n'
      '        config/         ← optional\n'
      '        repository/     ← optional\n'
      '        widgets/        ← optional\n'
      '        customWidgets/  ← optional\n'
      '      main.dart'
      '$reset',
    );

    print('');
    CliPrinter.divider();
    print('');
    print('$bold  👉  Set up LayerX Architecture first:$reset');
    print('');
    print(
      '  $cyan 1.$reset  Add $bold layerx_generator$reset to dev_dependencies:',
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
      '  $cyan 3.$reset  Generate structure, then re-run:',
    );
    print('$dim         dart run layerx_debugger:setup$reset');
    print('');
    CliPrinter.divider();
    print('');
    CliPrinter.info(
      'Setup aborted. Create the LayerX folder structure first, then retry.',
    );
    print('');

    return false;
  }
}
