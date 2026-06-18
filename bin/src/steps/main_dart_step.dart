import 'dart:io';

import '../utils/cli_printer.dart';

/// Wraps `lib/main.dart` with [LayerXDebugger.runZonedGuarded] and
/// injects [LayerXDebugger.initialize].
class MainDartStep {
  final String projectRoot;
  final String appName;

  MainDartStep(this.projectRoot, this.appName);

  static const _importLine =
      "import 'package:layerx_debugger/layerx_debugger.dart';";

  /// Returns true if main.dart was modified, false if already configured.
  bool run() {
    CliPrinter.step('Inspecting lib/main.dart ...');

    final mainFile = File('$projectRoot/lib/main.dart');
    if (!mainFile.existsSync()) {
      CliPrinter.warning(
        'lib/main.dart not found — skipping main wrap. '
        'Add LayerXDebugger.initialize() manually.',
      );
      return false;
    }

    var content = mainFile.readAsStringSync();

    // Already wrapped?
    if (content.contains('LayerXDebugger.runZonedGuarded') ||
        content.contains('LayerXDebugger.initialize')) {
      CliPrinter.skip('main.dart already uses LayerXDebugger');
      return false;
    }

    // --- 1. Add import if missing ---
    if (!content.contains(_importLine)) {
      // Place after last existing import block.
      final lastImport = _lastImportEnd(content);
      if (lastImport == -1) {
        content = '$_importLine\n\n$content';
      } else {
        content =
            '${content.substring(0, lastImport)}\n$_importLine'
            '${content.substring(lastImport)}';
      }
    }

    // --- 2. Locate the main() body braces ---
    final mainMatch = RegExp(r'void main\s*\(\s*\)\s*\{').firstMatch(content);
    if (mainMatch == null) {
      // Try `Future<void> main()` variant.
      final asyncMatch = RegExp(
        r'Future<void>\s+main\s*\(\s*\)\s*async\s*\{',
      ).firstMatch(content);
      if (asyncMatch == null) {
        CliPrinter.warning(
          'Could not locate `main()` in main.dart — wrap it manually.',
        );
        return false;
      }
      content = _wrapBody(content, asyncMatch, isAsync: true);
    } else {
      content = _wrapBody(content, mainMatch, isAsync: false);
    }

    // --- 3. Back up original ---
    File('$projectRoot/lib/main.dart.bak')
      ..createSync(recursive: true)
      ..writeAsStringSync(mainFile.readAsStringSync());

    mainFile.writeAsStringSync(content);
    CliPrinter.success('main.dart wrapped (backup at lib/main.dart.bak)');
    return true;
  }

  // ---------------------------------------------------------------------------

  /// Returns the index right after the last `import` line in [content],
  /// or -1 if no imports found.
  int _lastImportEnd(String content) {
    final matches = RegExp(r"^import\s+'[^']+';", multiLine: true)
        .allMatches(content);
    if (matches.isEmpty) return -1;
    final last = matches.last;
    return last.end;
  }

  /// Replaces the `void main() { ... }` block with the wrapped version.
  String _wrapBody(String content, Match mainMatch, {required bool isAsync}) {
    // Find the matching closing brace for the main function.
    final bodyStart = mainMatch.end; // index right after the opening `{`
    final closeIndex = _findMatchingBrace(content, bodyStart - 1);
    if (closeIndex == -1) {
      CliPrinter.warning('Could not parse main() body braces — wrap manually.');
      return content;
    }

    final originalBody = content.substring(bodyStart, closeIndex).trim();
    final indentedBody = originalBody
        .split('\n')
        .map((l) => '    $l')
        .join('\n');

    final escapedAppName = appName.replaceAll("'", "\\'");

    final replacement =
        'void main() {\n'
        '  LayerXDebugger.runZonedGuarded(() async {\n'
        '    WidgetsFlutterBinding.ensureInitialized();\n'
        '    await LayerXDebugger.initialize(\n'
        "      config: const LayerXDebugConfig(appName: '$escapedAppName'),\n"
        '    );\n'
        '$indentedBody\n'
        '  });\n'
        '}';

    return content.substring(0, mainMatch.start) +
        replacement +
        content.substring(closeIndex + 1);
  }

  /// Finds the index of the closing `}` that matches the `{` at [openIndex].
  int _findMatchingBrace(String s, int openIndex) {
    int depth = 0;
    for (var i = openIndex; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
