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

    // `runInShell` is required on Windows: `dart`/`flutter` are `.bat` shims
    // that `Process.run` cannot launch directly (it throws a ProcessException,
    // "The system cannot find the file specified"). Both calls are also
    // guarded so a failure in this final, best-effort step never aborts an
    // otherwise-successful setup.
    if (existing.isNotEmpty) {
      try {
        await Process.run('dart', ['format', ...existing],
            workingDirectory: projectRoot, runInShell: true);
        CliPrinter.success('Formatted ${existing.length} file(s).');
      } catch (e) {
        CliPrinter.warning('Could not format touched files ($e). Skipped.');
      }
    }

    try {
      final analyze = await Process.run('flutter', ['analyze'],
          workingDirectory: projectRoot, runInShell: true);
      if (analyze.exitCode == 0) {
        CliPrinter.success('flutter analyze passed — no issues.');
      } else {
        CliPrinter.warning(
          'flutter analyze reported issues (setup still completed). Review:\n'
          '${analyze.stdout}',
        );
      }
    } catch (e) {
      CliPrinter.warning(
        'Skipped `flutter analyze` — could not launch flutter ($e). '
        'Setup still completed; run `flutter analyze` yourself to check.',
      );
    }
  }
}
