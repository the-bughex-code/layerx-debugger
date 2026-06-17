import 'dart:io';

import '../utils/cli_printer.dart';

/// Injects [layerx_debugger] into the target project's pubspec.yaml
/// and runs `flutter pub get`.
class PubspecStep {
  final String projectRoot;

  PubspecStep(this.projectRoot);

  /// Returns true if the dependency was newly added, false if already present.
  Future<bool> run() async {
    CliPrinter.step('Checking pubspec.yaml ...');

    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      CliPrinter.error(
        'pubspec.yaml not found in $projectRoot. '
        'Are you running this from a Flutter project root?',
      );
      exit(1);
    }

    var content = pubspecFile.readAsStringSync();

    // Already added?
    if (content.contains('layerx_debugger:')) {
      CliPrinter.skip('layerx_debugger already in pubspec.yaml');
      return false;
    }

    // Inject after the `dependencies:` block opening line.
    // We look for `dependencies:` and insert right after it.
    const marker = 'dependencies:';
    final depIndex = content.indexOf(marker);
    if (depIndex == -1) {
      CliPrinter.error(
        'Could not find `dependencies:` section in pubspec.yaml.',
      );
      exit(1);
    }

    // Insert after the `dependencies:` line.
    final insertAt = depIndex + marker.length;
    content =
        '${content.substring(0, insertAt)}\n'
        '  layerx_debugger: ^1.0.0'
        '${content.substring(insertAt)}';

    pubspecFile.writeAsStringSync(content);
    CliPrinter.success('layerx_debugger ^1.0.0 added to pubspec.yaml');

    // Run flutter pub get.
    CliPrinter.step('Running flutter pub get ...');
    final result = await Process.run(
      'flutter',
      ['pub', 'get'],
      workingDirectory: projectRoot,
    );

    if (result.exitCode != 0) {
      CliPrinter.error('flutter pub get failed:\n${result.stderr}');
      exit(1);
    }
    CliPrinter.success('flutter pub get succeeded');
    return true;
  }
}
