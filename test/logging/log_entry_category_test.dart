import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';

LayerXLogEntry _entry() => LayerXLogEntry(
      id: '1',
      dedupKey: 'k',
      timestamp: DateTime(2026),
      level: LayerXLogLevel.info,
      source: LayerXLogSource.app,
      message: 'm',
      journey: const [],
      extras: const {},
    );

void main() {
  test('category defaults to app and location defaults to null', () {
    final e = _entry();
    expect(e.category, LayerXLogCategory.app);
    expect(e.sourceFile, isNull);
    expect(e.sourceLine, isNull);
  });

  test('copyWith round-trips category and source location', () {
    final e = _entry().copyWith(
      category: LayerXLogCategory.debugConsole,
      sourceFile: 'lib/main.dart',
      sourceLine: 42,
    );
    expect(e.category, LayerXLogCategory.debugConsole);
    expect(e.sourceFile, 'lib/main.dart');
    expect(e.sourceLine, 42);
  });
}
