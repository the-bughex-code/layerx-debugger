import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/integration/http_binder.dart';

void main() {
  group('bindDio', () {
    const dioSrc = '''
class Net {
  final dio = Dio();
}
''';
    test('adds interceptor after Dio() and dio.dart import', () {
      final out = bindDio(dioSrc)!;
      expect(out, contains('LayerXDioInterceptor()'));
      expect(out, contains('interceptors.add'));
      expect(out, contains('package:layerx_debugger/dio.dart'));
    });
    test('idempotent', () {
      final once = bindDio(dioSrc)!;
      expect(bindDio(once), isNull);
    });
    test('null when no Dio()', () => expect(bindDio('class X {}'), isNull));
  });

  group('bindHttpLegacy', () {
    const legacy = '''
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
    test('rewrites LxHttpInterceptor.record to LayerXNetworkLogger.record', () {
      final out = bindHttpLegacy(legacy)!;
      expect(out, contains('LayerXNetworkLogger.record('));
      expect(out, contains('statusCode: r.statusCode'));
      expect(out, contains('responseBody: r.body'));
      expect(out, isNot(contains('LxHttpInterceptor')));
    });
    test('null when no legacy call',
        () => expect(bindHttpLegacy('class X {}'), isNull));
  });
}
