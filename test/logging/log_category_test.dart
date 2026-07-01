import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';

void main() {
  test('every category exposes a non-empty label, a color and an icon', () {
    for (final c in LayerXLogCategory.values) {
      expect(c.label, isNotEmpty, reason: '${c.name} label');
      expect(c.color, isA<Color>());
      expect(c.icon, isA<IconData>());
    }
  });

  test('covers the 12 product buckets', () {
    expect(LayerXLogCategory.values.map((c) => c.name).toSet(), {
      'app', 'framework', 'uiException', 'dartException', 'network', 'api',
      'navigation', 'lifecycle', 'performance', 'crash', 'debugConsole',
      'system',
    });
  });
}
