import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/utils/layerx_stack_location.dart';

void main() {
  test('extracts file and line from the first app frame', () {
    const trace = '#0      MyClass.method (package:my_app/screens/home.dart:42:13)\n'
        '#1      main (package:my_app/main.dart:5:3)';
    final loc = LayerXStackLocation.parse(trace, packageName: 'my_app');
    expect(loc.file, 'package:my_app/screens/home.dart');
    expect(loc.line, 42);
  });

  test('skips layerx frames when no package name is given', () {
    const trace = '#0      LayerXLog._emit (package:layerx_debugger/x.dart:9:1)\n'
        '#1      Foo.bar (package:app/foo.dart:7:2)';
    final loc = LayerXStackLocation.parse(trace);
    expect(loc.file, 'package:app/foo.dart');
    expect(loc.line, 7);
  });

  test('returns nulls when no usable frame exists', () {
    final loc = LayerXStackLocation.parse('no frames here');
    expect(loc.file, isNull);
    expect(loc.line, isNull);
  });
}
