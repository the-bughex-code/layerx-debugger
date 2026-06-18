/// LayerX Debugger — Auto Setup CLI
///
/// Run from your Flutter project root:
///   dart run layerx_debugger:setup
///
/// What it does:
///   0. Scans for LayerX architecture — aborts with guidance if not found
///   1. Adds layerx_debugger + layerx_generator to pubspec and runs flutter pub get
///   2. Wraps lib/main.dart with LayerXDebugger.runZonedGuarded + initialize
///   3. Injects LayerXDebugOverlay builder into MaterialApp / GetMaterialApp
///   4. Binds LoggerService and HttpsCalls with LayerX Debugger automatically
library;

import 'dart:io';

import 'src/integration/integration_scanner.dart';
import 'src/steps/app_widget_step.dart';
import 'src/steps/http_bind_step.dart';
import 'src/steps/layerx_detector_step.dart';
import 'src/steps/logger_bind_step.dart';
import 'src/steps/main_dart_step.dart';
import 'src/steps/pubspec_step.dart';
import 'src/steps/verify_step.dart';
import 'src/utils/cli_printer.dart';

Future<void> main(List<String> args) async {
  CliPrinter.header();

  // ── Resolve target project directory ──────────────────────────────────────
  // Default: current working directory.
  // Allows: dart run layerx_debugger:setup /path/to/project
  final projectRoot = args.isNotEmpty ? args.first : Directory.current.path;

  CliPrinter.info('Target project: $projectRoot');
  CliPrinter.divider();

  // ── Validate Flutter project ───────────────────────────────────────────────
  final pubspecFile = File('$projectRoot/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    CliPrinter.error(
      'No pubspec.yaml found at $projectRoot.\n'
      '  Run this command from the root of a Flutter project.',
    );
    exit(1);
  }

  // Extract project/app name from pubspec for the config appName.
  final pubspecContent = pubspecFile.readAsStringSync();
  final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true)
      .firstMatch(pubspecContent);
  final rawName = nameMatch?.group(1)?.trim() ?? 'My App';
  // Convert snake_case → Title Case for appName.
  final appName = rawName
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  CliPrinter.info('Detected app name: $appName');
  CliPrinter.divider();

  // ── Step 0: LayerX Architecture Detection ─────────────────────────────────
  // Abort early if the project is not following LayerX pattern.
  final detector = LayerXDetectorStep(projectRoot);
  final detectionResult = detector.run();
  final shouldContinue = detector.printAndDecide(detectionResult);
  CliPrinter.divider();

  if (!shouldContinue) {
    exit(0); // graceful exit — user needs to set up LayerX first
  }

  // ── Step 1: pubspec.yaml ───────────────────────────────────────────────────
  final pubspecDone = await PubspecStep(projectRoot).run();
  CliPrinter.divider();

  // ── Step 2: main.dart ─────────────────────────────────────────────────────
  final mainDone = MainDartStep(projectRoot, appName).run();
  CliPrinter.divider();

  // ── Step 3: MaterialApp / GetMaterialApp ───────────────────────────────────
  final appWidgetFile = AppWidgetStep(projectRoot).run();
  CliPrinter.divider();

  // ── Step 4: Scan integration targets (content-based) ──────────────────────
  final targets = IntegrationScanner(projectRoot).scan();

  // ── Step 5: Bind logger (aborts if missing) ────────────────────────────────
  LoggerBindStep(targets.logger).run();
  CliPrinter.divider();

  // ── Step 6: Bind HTTP layer (graceful skip if missing) ─────────────────────
  final servicesBound = HttpBindStep(targets).run();
  CliPrinter.divider();

  // ── Step 7: Verify (format touched files + analyze, report only) ───────────
  final touched = <String>[
    if (targets.logger.found) targets.logger.filePath!,
    if (targets.dio.found) targets.dio.filePath!,
    if (targets.httpWrap.found) targets.httpWrap.filePath!,
  ];
  await VerifyStep(projectRoot, touched).run();
  CliPrinter.divider();

  // ── Summary ────────────────────────────────────────────────────────────────
  CliPrinter.summary(
    pubspecDone: pubspecDone,
    mainDone: mainDone,
    appWidgetFile: appWidgetFile,
    servicesBound: servicesBound,
  );
}
