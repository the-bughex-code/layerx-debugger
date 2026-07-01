import 'dart:io';

import '../integration/app_widget_binder.dart';
import '../utils/cli_printer.dart';

/// Scans all Dart files under `lib/` for [MaterialApp] or [GetMaterialApp]
/// and injects:
///   - `builder: (context, child) => LayerXDebugOverlay(child: child!),`
///   - `navigatorObservers: [LayerXDebugger.routeObserver],`
class AppWidgetStep {
  final String projectRoot;

  AppWidgetStep(this.projectRoot);

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
    final original = file.readAsStringSync();
    final result = bindAppWidget(original);
    if (result == null) return false; // no app widget, or already wrapped

    // Back up and write.
    File('${file.path}.bak').writeAsStringSync(original);
    file.writeAsStringSync(result.source);

    final name = file.path.split(Platform.pathSeparator).last;
    CliPrinter.success(
      'LayerXDebugOverlay wired in $name (backup .bak created)',
    );

    // The app already had its own `builder:`. We must not add a second one
    // (duplicate named argument = compile error), so wrapping is left to the
    // user — otherwise the overlay never renders.
    if (result.builderSkipped) {
      CliPrinter.warning(
        '$name already defines a `builder:` — left untouched to avoid a '
        'duplicate argument. Wrap its returned child with LayerXDebugOverlay '
        'so the in-app debugger shows, e.g.:\n'
        '  builder: (context, child) => LayerXDebugOverlay(\n'
        '    child: /* your existing builder result */ child!,\n'
        '  ),',
      );
    }
    return true;
  }
}
