import 'dart:io';

import '../integration/http_binder.dart';
import '../integration/integration_targets.dart';
import '../utils/cli_printer.dart';

/// Binds the HTTP layer: Dio interceptor and/or legacy http record() rewrite.
/// Skips gracefully (returns false) when no HTTP service is detected.
class HttpBindStep {
  final IntegrationTargets targets;
  HttpBindStep(this.targets);

  /// Returns true if any HTTP integration was applied.
  bool run() {
    CliPrinter.step('Binding HTTP layer ...');
    if (!targets.anyHttp) {
      CliPrinter.info(
        'No HTTP/dio service detected — network interception skipped. '
        'Add an HttpService or Dio client and re-run setup to enable it.',
      );
      return false;
    }
    var changed = false;

    if (targets.dio.found) {
      changed = _patch(targets.dio.filePath!, bindDio,
              'Dio client bound with LayerXDioInterceptor.') ||
          changed;
    }
    if (targets.httpWrap.found) {
      final applied = _patch(
        targets.httpWrap.filePath!,
        bindHttpLegacy,
        '${targets.httpWrap.className} bound with LayerXNetworkLogger.',
      );
      if (!applied) {
        CliPrinter.warning(
          'Could not auto-inject into ${targets.httpWrap.className}. '
          'Add this at your response site:\n$httpGuidedSnippet',
        );
      }
      changed = applied || changed;
    }
    return changed;
  }

  bool _patch(String path, String? Function(String) binder, String okMsg) {
    final file = File(path);
    final src = file.readAsStringSync();
    final patched = binder(src);
    if (patched == null) return false;
    final bak = File('${file.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(src);
    file.writeAsStringSync(patched);
    CliPrinter.success(okMsg);
    return true;
  }
}
