import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  group('LayerXHttpClient', () {
    test('captures a GET routed through any inner client and keeps the body',
        () async {
      final client = LayerXHttpClient(
        MockClient(
          (req) async => http.Response(
            '{"ok":true}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final res = await client.get(Uri.parse('https://api.test/users'));

      // Caller must receive an intact response (stream not consumed by logging).
      expect(res.statusCode, 200);
      expect(res.body, '{"ok":true}');

      final entry = LayerXLogStore.logs.first;
      expect(entry.statusCode, 200);
      expect(entry.level, LayerXLogLevel.success);
      expect(entry.endpoint, contains('/users'));
    });

    test('captures the request body and masks secrets', () async {
      final client = LayerXHttpClient(
        MockClient((req) async => http.Response('{}', 201)),
      );

      await client.post(
        Uri.parse('https://api.test/login'),
        headers: {'Authorization': 'Bearer abc'},
        body: '{"password":"hunter2"}',
      );

      final entry = LayerXLogStore.logs.first;
      expect(entry.message, contains('POST'));
      expect(entry.requestPayload, isNotNull);
      expect(entry.requestPayload, isNot(contains('hunter2')));
    });

    test('records a transport exception and rethrows it', () async {
      final client = LayerXHttpClient(
        MockClient((req) async => throw Exception('connection refused')),
      );

      await expectLater(
        client.get(Uri.parse('https://api.test/down')),
        throwsA(isA<Exception>()),
      );

      final errors = LayerXLogStore.logs
          .where((l) => l.level == LayerXLogLevel.error)
          .toList();
      expect(errors, isNotEmpty);
      expect(errors.first.endpoint, contains('/down'));
    });
  });
}
