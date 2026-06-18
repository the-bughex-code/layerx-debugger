import 'dart:io';

import '../utils/cli_printer.dart';

/// Formats the files the CLI touched and runs `flutter analyze`, reporting any
/// issues without failing setup. Directly serves the "no broken files" goal.
class VerifyStep {
  final String projectRoot;
  final List<String> touchedFiles;
  VerifyStep(this.projectRoot, this.touchedFiles);

  Future<void> run() async {
    CliPrinter.step('Verifying changes ...');
    final existing = touchedFiles.where((p) => File(p).existsSync()).toList();
    if (existing.isNotEmpty) {
      await Process.run('dart', ['format', ...existing],
          workingDirectory: projectRoot);
      CliPrinter.success('Formatted ${existing.length} file(s).');
    }
    final analyze = await Process.run('flutter', ['analyze'],
        workingDirectory: projectRoot);
    if (analyze.exitCode == 0) {
      CliPrinter.success('flutter analyze passed — no issues.');
    } else {
      CliPrinter.warning(
        'flutter analyze reported issues (setup still completed). Review:\n'
        '${analyze.stdout}',
      );
    }
  }
}
