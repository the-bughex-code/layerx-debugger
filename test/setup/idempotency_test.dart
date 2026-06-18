import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/integration/http_binder.dart';
import '../../bin/src/integration/logger_binder.dart';

void main() {
  test('logger binder: running twice equals running once', () {
    const src = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(output: ConsoleOutput());
}
''';
    final once = bindLogger(src)!;
    final twice = bindLogger(once);
    expect(twice, isNull, reason: 'second pass must be a no-op');
  });

  test('dio binder: running twice equals running once', () {
    const src = 'class N { final dio = Dio(); }';
    final once = bindDio(src)!;
    expect(bindDio(once), isNull);
  });

  test('http legacy binder: running twice equals running once', () {
    const src = '''
class HttpsCalls {
  void f(r, body) {
    LxHttpInterceptor.record(
      endpoint: ep,
      method: m,
      response: r,
      requestBody: body,
      durationMs: 10,
    );
  }
}
''';
    final once = bindHttpLegacy(src)!;
    final twice = bindHttpLegacy(once);
    expect(twice, isNull,
        reason: 'no LxHttpInterceptor.record calls remain after first pass');
  });
}
