import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

Route<dynamic> _route(String name) => PageRouteBuilder<dynamic>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  group('LayerXRouteObserver', () {
    test('logs a push with the route name', () {
      LayerXRouteObserver().didPush(_route('/home'), null);

      final entry = LayerXLogStore.logs.first;
      expect(entry.level, LayerXLogLevel.info);
      expect(entry.serviceName, 'Navigation');
      expect(entry.message, contains('/home'));
      expect(entry.extras['action'], 'PUSH');
    });

    test('respects enableRouteLogs', () async {
      await LayerXDebugger.initialize(
        config: const LayerXDebugConfig(enableRouteLogs: false),
      );
      LayerXLogStore.clear();

      LayerXRouteObserver().didPush(_route('/x'), null);

      expect(LayerXLogStore.logs, isEmpty);
    });
  });

  group('LayerXRouteMiddleware', () {
    test('logs the redirected route and does not redirect', () {
      final result = LayerXRouteMiddleware().redirect('/profile');

      expect(result, isNull);
      expect(
        LayerXLogStore.logs.any((e) => e.message.contains('/profile')),
        isTrue,
      );
    });
  });
}
