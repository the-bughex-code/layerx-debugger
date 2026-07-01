import 'dart:io';

import '../utils/cli_printer.dart';

/// Whether [path] parses as valid Dart, using `dart format` as a cheap,
/// dependency-free syntax gate (it exits 65 when the source can't be parsed).
/// Best-effort: if `dart` can't be launched we assume the file is fine so the
/// guard never destroys work it couldn't actually verify.
Future<bool> _parses(String projectRoot, String path) async {
  try {
    final r = await Process.run(
      'dart',
      ['format', '--output=none', path],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    return r.exitCode == 0;
  } catch (_) {
    return true;
  }
}

/// Safety net for the regex-based source edits: if an injection left a touched
/// file that no longer parses, roll it back from the `.bak` the step wrote
/// before editing. This guarantees setup never leaves the host app in a
/// non-compiling state — a bad edit degrades to "file untouched" instead of a
/// broken build. Returns the paths that were reverted.
Future<List<String>> revertUnparseableFiles(
    String projectRoot, List<String> touchedFiles) async {
  final reverted = <String>[];
  for (final path in touchedFiles) {
    if (!File(path).existsSync()) continue;
    if (await _parses(projectRoot, path)) continue;
    final bak = File('$path.bak');
    if (!bak.existsSync()) continue; // nothing to restore — leave it for analyze
    bak.copySync(path);
    reverted.add(path);
  }
  return reverted;
}

/// Formats the files the CLI touched and runs `flutter analyze`, reporting any
/// issues without failing setup. Directly serves the "no broken files" goal.
class VerifyStep {
  final String projectRoot;
  final List<String> touchedFiles;
  VerifyStep(this.projectRoot, this.touchedFiles);

  Future<void> run() async {
    CliPrinter.step('Verifying changes ...');
    var existing = touchedFiles.where((p) => File(p).existsSync()).toList();

    // Roll back any edit that produced unparseable Dart before doing anything
    // else, so a bad injection can never reach the user's build.
    final reverted = await revertUnparseableFiles(projectRoot, existing);
    if (reverted.isNotEmpty) {
      CliPrinter.warning(
        'Auto-reverted ${reverted.length} file(s) an edit would have broken '
        '(restored from .bak):\n  ${reverted.join('\n  ')}\n'
        'These were left untouched — wire LayerX into them manually '
        '(see the README) and re-run setup.',
      );
      existing = existing.where((p) => !reverted.contains(p)).toList();
    }

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
