import 'dart:io';

import '../integration/integration_targets.dart';
import '../integration/logger_binder.dart';
import '../utils/cli_printer.dart';

/// Binds the detected LoggerService. Aborts the process if no logger exists —
/// without it, LayerX cannot capture logs.
class LoggerBindStep {
  final LoggerTarget target;
  LoggerBindStep(this.target);

  /// Returns true if logging was bound (or already bound).
  bool run() {
    CliPrinter.step('Binding LoggerService ...');
    if (!target.found) {
      CliPrinter.error(
        'LayerX LoggerService was not found. Integration cannot continue '
        'because logs will not be captured.',
      );
      exit(1);
    }
    final file = File(target.filePath!);
    final src = file.readAsStringSync();
    final patched = bindLogger(src);
    if (patched == null) {
      CliPrinter.skip('${target.className} already bound — no changes.');
      return true;
    }
    final bak = File('${file.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(src);
    file.writeAsStringSync(patched);
    CliPrinter.success(
      '${target.className} bound with LayerXLogInterceptorOutput.',
    );
    return true;
  }
}
