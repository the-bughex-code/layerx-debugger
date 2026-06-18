import 'dart:io';

import '../utils/cli_printer.dart';

/// Scans all Dart files under `lib/` for [MaterialApp] or [GetMaterialApp]
/// and injects:
///   - `builder: (context, child) => LayerXDebugOverlay(child: child!),`
///   - `navigatorObservers: [LayerXDebugger.routeObserver],`
class AppWidgetStep {
  final String projectRoot;

  AppWidgetStep(this.projectRoot);

  static const _importLine =
      "import 'package:layerx_debugger/layerx_debugger.dart';";

  /// Returns the path (relative to projectRoot) of the first file modified,
  /// or null if nothing was changed.
  String? run() {
    CliPrinter.step(
      'Scanning lib/ for MaterialApp / GetMaterialApp ...',
    );

    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      CliPrinter.warning('lib/ directory not found — skipping overlay inject.');
      return null;
    }

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    String? firstModified;

    for (final file in dartFiles) {
      final result = _processFile(file);
      if (result && firstModified == null) {
        firstModified = file.path.replaceFirst('$projectRoot/', '');
      }
    }

    if (firstModified == null) {
      CliPrinter.skip(
        'No unmodified MaterialApp/GetMaterialApp found (or already wrapped)',
      );
    }
    return firstModified;
  }

  // ---------------------------------------------------------------------------

  bool _processFile(File file) {
    var content = file.readAsStringSync();

    // Skip if already using LayerXDebugOverlay in this file.
    if (content.contains('LayerXDebugOverlay')) return false;

    // Check whether file contains a MaterialApp or GetMaterialApp constructor.
    final appPattern = RegExp(r'\b(GetMaterialApp|MaterialApp)\s*\(');
    if (!appPattern.hasMatch(content)) return false;

    // --- Add import if missing ---
    if (!content.contains(_importLine)) {
      content = _injectImport(content);
    }

    // --- Inject builder: and navigatorObservers: into every match ---
    content = _injectIntoAllMatches(content, appPattern);

    // Back up and write.
    File('${file.path}.bak').writeAsStringSync(file.readAsStringSync());
    file.writeAsStringSync(content);

    CliPrinter.success(
      'LayerXDebugOverlay injected in '
      '${file.path.split('/').last} (backup .bak created)',
    );
    return true;
  }

  /// Inserts the LayerX import after the last existing import line.
  String _injectImport(String content) {
    final matches = RegExp(r"^import\s+'[^']+';", multiLine: true)
        .allMatches(content);
    if (matches.isEmpty) return '$_importLine\n\n$content';
    final last = matches.last;
    return '${content.substring(0, last.end)}\n$_importLine'
        '${content.substring(last.end)}';
  }

  /// Iterates over each [MaterialApp]/[GetMaterialApp] opening `(` and injects
  /// the builder + navigatorObservers parameters as the first params.
  String _injectIntoAllMatches(String content, RegExp appPattern) {
    // Work backwards so that string indices remain valid after insertion.
    final matches = appPattern.allMatches(content).toList().reversed;
    for (final match in matches) {
      final parenIdx = match.end - 1; // index of the `(`
      if (parenIdx >= content.length || content[parenIdx] != '(') continue;

      // Find indentation level by looking at the line start.
      final lineStart = content.lastIndexOf('\n', parenIdx) + 1;
      final lineContent = content.substring(lineStart, parenIdx);
      final indent = ' ' * (lineContent.length - lineContent.trimLeft().length);
      final paramIndent = '$indent  ';

      // Only inject if builder/navigatorObservers are not already present
      // within this app call's braces.
      final closeIdx = _findMatchingParen(content, parenIdx);
      if (closeIdx == -1) continue;
      final callBody = content.substring(parenIdx, closeIdx);
      if (callBody.contains('LayerXDebugOverlay') ||
          callBody.contains('layerx_debugger') &&
              callBody.contains('builder')) {
        continue;
      }

      final injection =
          '\n${paramIndent}builder: (context, child) =>'
          ' LayerXDebugOverlay(child: child!),'
          '\n${paramIndent}navigatorObservers: [LayerXDebugger.routeObserver],';

      content =
          content.substring(0, parenIdx + 1) +
          injection +
          content.substring(parenIdx + 1);
    }
    return content;
  }

  int _findMatchingParen(String s, int openIndex) {
    int depth = 0;
    for (var i = openIndex; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
