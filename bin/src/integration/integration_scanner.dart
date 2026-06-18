import 'dart:io';

import 'integration_targets.dart';

/// Scans `lib/app/**` of a LayerX project for the services the CLI must bind:
/// a `logger`-package Logger, a Dio client, and/or an `http`-based wrapper.
///
/// Detection is content-based (not path-hardcoded) so renamed service classes
/// are still found.
class IntegrationScanner {
  final String projectRoot;
  IntegrationScanner(this.projectRoot);

  static final _loggerRe =
      RegExp(r'static\s+final\s+Logger\s+\w+\s*=\s*Logger\(');
  static final _classRe = RegExp(r'class\s+(\w+)');
  static final _dioRe = RegExp(r'\bDio\s*\(');
  static final _httpNameRe =
      RegExp(r'class\s+(\w*(?:Http|Api|Network)\w*|HttpsCalls)\b');

  IntegrationTargets scan() {
    LoggerTarget logger = const LoggerTarget.notFound();
    DioTarget dio = const DioTarget.notFound();
    HttpWrapTarget httpWrap = const HttpWrapTarget.notFound();

    final appDir = Directory('$projectRoot/lib/app');
    if (!appDir.existsSync()) {
      return IntegrationTargets(logger: logger, dio: dio, httpWrap: httpWrap);
    }

    final dartFiles = appDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in dartFiles) {
      final src = f.readAsStringSync();
      if (!logger.found && _loggerRe.hasMatch(src)) {
        final name = _classRe.firstMatch(src)?.group(1) ?? 'LoggerService';
        logger = LoggerTarget.at(f.path, name);
      }
      if (!dio.found && _dioRe.hasMatch(src)) {
        dio = DioTarget.at(f.path);
      }
      if (!httpWrap.found &&
          src.contains('package:http/http.dart') &&
          _httpNameRe.hasMatch(src)) {
        final name = _httpNameRe.firstMatch(src)!.group(1)!;
        httpWrap = HttpWrapTarget.at(f.path, name);
      }
    }
    return IntegrationTargets(logger: logger, dio: dio, httpWrap: httpWrap);
  }
}
