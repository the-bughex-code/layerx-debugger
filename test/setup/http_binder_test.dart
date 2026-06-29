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

  group('bindHttpClient', () {
    const ioClientSrc = '''
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class HttpsCalls {
  late final IOClient _client = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 30),
  );
}
''';

    test('wraps the IOClient field with LayerXHttpClient', () {
      final out = bindHttpClient(ioClientSrc)!;
      expect(out, contains('LayerXHttpClient(IOClient('));
      // The field type is widened so the wrapped client type-checks.
      expect(out, contains('http.Client _client ='));
      expect(out, isNot(contains('IOClient _client')));
      expect(out, contains('package:layerx_debugger/layerx_debugger.dart'));
      // Parentheses stay balanced (one extra close added before the `;`).
      expect('('.allMatches(out).length, ')'.allMatches(out).length);
    });

    test('is idempotent', () {
      final once = bindHttpClient(ioClientSrc)!;
      expect(bindHttpClient(once), isNull);
    });

    test('wraps a plain http.Client() too', () {
      const s = '''
import 'package:http/http.dart' as http;
class Api { final http.Client _c = http.Client(); }
''';
      final out = bindHttpClient(s)!;
      expect(out, contains('LayerXHttpClient(http.Client())'));
    });

    test('null when no client construction is present',
        () => expect(bindHttpClient('class X {}'), isNull));
  });
}
