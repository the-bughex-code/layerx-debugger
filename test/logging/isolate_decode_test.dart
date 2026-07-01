import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/crash/layerx_isolate_hook_io.dart';

void main() {
  test('decodes [error, stack] pair into a message and stack trace', () {
    final decoded = decodeIsolateError(['Boom', '#0 main (a.dart:1:1)']);
    expect(decoded.message, 'Boom');
    expect(decoded.stack.toString(), contains('a.dart'));
  });

  test('handles a null stack element', () {
    final decoded = decodeIsolateError(['Boom', null]);
    expect(decoded.message, 'Boom');
    expect(decoded.stack, StackTrace.empty);
  });
}
