import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/integration/logger_binder.dart';

const _consoleOutput = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    level: Level.trace,
    output: ConsoleOutput(),
  );
}
''';

void main() {
  test('injects LayerXLogInterceptorOutput into ConsoleOutput-only logger', () {
    final out = bindLogger(_consoleOutput)!;
    expect(out, contains('LayerXLogInterceptorOutput()'));
    expect(out, contains('MultiOutput('));
    expect(out, contains('package:layerx_debugger/layerx_debugger.dart'));
  });

  test('is idempotent — second run returns null (already bound)', () {
    final once = bindLogger(_consoleOutput)!;
    expect(bindLogger(once), isNull);
  });

  test('returns null for a non-logger file', () {
    expect(bindLogger('class Foo {}'), isNull);
  });

  test('replaces legacy LxLogOutput with LayerXLogInterceptorOutput', () {
    const legacy = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    output: MultiOutput([ConsoleOutput(), LxLogOutput()]),
  );
}
''';
    final out = bindLogger(legacy)!;
    expect(out, contains('LayerXLogInterceptorOutput()'));
    expect(out, isNot(contains('LxLogOutput()')));
  });

  test('adds output param when none exists', () {
    const noOutput = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    level: Level.trace,
  );
}
''';
    final out = bindLogger(noOutput)!;
    expect(out, contains('output:'));
    expect(out, contains('LayerXLogInterceptorOutput()'));
  });
}
