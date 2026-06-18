import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/config/utils/layerx_console_printer.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
  });

  group('LayerXLog', () {
    test('success is stored with the success level', () {
      LayerXLog.s('great');
      expect(LayerXLogStore.logs, isNotEmpty);
      expect(LayerXLogStore.logs.first.level, LayerXLogLevel.success);
      expect(LayerXLogStore.logs.first.message, 'great');
    });

    test('error is captured into the store', () {
      LayerXLog.e('boom');
      expect(LayerXLogStore.logs.first.level, LayerXLogLevel.error);
      expect(LayerXLogStore.logs.first.message, contains('boom'));
    });

    test('structured log records endpoint + status', () {
      LayerXLog.log(
        level: LayerXLogLevel.warning,
        message: 'slow call',
        endpoint: '/users',
        statusCode: 200,
      );
      final entry = LayerXLogStore.logs.first;
      expect(entry.endpoint, '/users');
      expect(entry.statusCode, 200);
    });

    test('production suppresses debug and success', () async {
      await LayerXDebugger.initialize(
        config: const LayerXDebugConfig(environment: LayerXEnvironment.prod),
      );
      LayerXLogStore.clear();

      LayerXLog.d('hidden');
      LayerXLog.s('nope');

      expect(LayerXLogStore.logs, isEmpty);
    });
  });

  group('LayerXConsolePrinter', () {
    test('box wraps content between ┌ and └', () {
      final lines = LayerXConsolePrinter.box(
        title: 'API REQUEST',
        lines: ['GET /users', 'Headers:'],
        colors: false,
      );
      expect(lines.first.startsWith('┌'), isTrue);
      expect(lines.last.startsWith('└'), isTrue);
      expect(lines.any((l) => l.contains('API REQUEST')), isTrue);
      expect(lines.any((l) => l.contains('GET /users')), isTrue);
    });

    test('colored success line uses the green ANSI code', () {
      final line = LayerXConsolePrinter.formatLine(
        LayerXLogLevel.success,
        'ok',
        colors: true,
      );
      expect(line, contains('\x1B[32m'));
      expect(line, contains('SUCCESS'));
    });

    test('uncolored line omits ANSI codes', () {
      final line = LayerXConsolePrinter.formatLine(
        LayerXLogLevel.info,
        'plain',
        colors: false,
      );
      expect(line.contains('\x1B'), isFalse);
      expect(line, contains('INFO'));
    });
  });
}
