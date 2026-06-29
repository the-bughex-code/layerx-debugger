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
      final path = targets.httpWrap.filePath!;
      final cls = targets.httpWrap.className;

      // Prefer wrapping the underlying client with LayerXHttpClient — one
      // robust edit that captures the whole API surface. Only fall back to
      // rewriting legacy per-call interceptor hooks when there's no client to
      // wrap, so the same request is never logged twice.
      var applied = _patch(
        path,
        bindHttpClient,
        '$cls now routes through LayerXHttpClient — every request is captured.',
      );
      if (!applied) {
        applied = _patch(
          path,
          bindHttpLegacy,
          '$cls legacy interceptor calls bound to LayerXNetworkLogger.',
        );
      }
      if (!applied) {
        CliPrinter.warning(
          'Could not auto-inject into $cls. '
          'Wrap your http client once:\n'
          '  final client = LayerXHttpClient(yourExistingClient);\n'
          'or add this at your response site:\n$httpGuidedSnippet',
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
