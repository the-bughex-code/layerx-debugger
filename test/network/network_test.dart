import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  group('LayerXNetworkLogger', () {
    test('logs a 2xx as success', () {
      LayerXNetworkLogger.record(
        endpoint: '/users',
        method: 'GET',
        statusCode: 200,
        responseBody: '{"ok":true}',
        durationMs: 12,
      );
      final entry = LayerXLogStore.logs.first;
      expect(entry.level, LayerXLogLevel.success);
      expect(entry.statusCode, 200);
    });

    test('masks sensitive headers and body fields', () {
      LayerXNetworkLogger.record(
        endpoint: '/login',
        method: 'POST',
        statusCode: 200,
        requestBody: '{"password":"hunter2"}',
        requestHeaders: {'Authorization': 'Bearer abc'},
        responseBody: '{}',
      );
      final entry = LayerXLogStore.logs.first;
      expect(entry.requestPayload, contains('********'));
      expect(entry.requestPayload, isNot(contains('hunter2')));
    });

    test('logs a 5xx as a server error with a suggestion', () {
      LayerXNetworkLogger.record(
        endpoint: '/x',
        method: 'GET',
        statusCode: 500,
        responseBody: '{"message":"boom"}',
      );
      final entry = LayerXLogStore.logs.first;
      expect(entry.level, LayerXLogLevel.error);
      expect(entry.source, LayerXLogSource.server);
      expect(entry.suggestedSolution, isNotNull);
    });
  });

  group('LayerXHttp', () {
    test('records a GET made through the wrapper', () async {
      LayerXHttp.client = MockClient(
        (request) async => http.Response(
          '{"ok":true}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final response =
          await LayerXHttp.get(Uri.parse('https://api.test/users'));

      expect(response.statusCode, 200);
      expect(LayerXLogStore.logs.first.statusCode, 200);
      expect(LayerXLogStore.logs.first.level, LayerXLogLevel.success);
    });

    test('records a PATCH made through the wrapper', () async {
      LayerXHttp.client =
          MockClient((request) async => http.Response('{}', 200));

      await LayerXHttp.patch(
        Uri.parse('https://api.test/users/1'),
        body: '{"name":"new"}',
      );

      expect(LayerXLogStore.logs.first.message, contains('PATCH'));
    });
  });
}
