import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/config/utils/layerx_duplicate_guard.dart';

LayerXLogEntry _entry({
  required String id,
  LayerXLogLevel level = LayerXLogLevel.info,
  String message = 'm',
  String? endpoint,
  String? response,
  DateTime? at,
}) {
  return LayerXLogEntry(
    id: id,
    dedupKey: 'key',
    timestamp: at ?? DateTime(2026),
    level: level,
    source: LayerXLogSource.app,
    message: message,
    endpoint: endpoint,
    responsePayload: response,
    journey: const [],
    extras: const {},
  );
}

void main() {
  setUp(() {
    LayerXLogStore.clear();
    LayerXLogStore.maxStoredLogs = 500;
  });

  test('add inserts newest first and counts errors', () {
    LayerXLogStore.add(_entry(id: '1'));
    LayerXLogStore.add(_entry(id: '2', level: LayerXLogLevel.error));

    expect(LayerXLogStore.logs.first.id, '2');
    expect(LayerXLogStore.logs.length, 2);
    expect(LayerXLogStore.errorCount, 1);
  });

  test('detects API response changes for the same endpoint', () {
    LayerXLogStore.add(_entry(id: '1', endpoint: '/x', response: '{"a":1}'));
    LayerXLogStore.add(_entry(id: '2', endpoint: '/x', response: '{"a":2}'));

    final latest = LayerXLogStore.logs.first;
    expect(latest.responseChanged, isTrue);
    expect(latest.schemaChanges, isNotEmpty);
    expect(LayerXLogStore.schemaChangeCount, 1);
  });

  test('trims to maxStoredLogs', () {
    LayerXLogStore.maxStoredLogs = 2;
    LayerXLogStore.add(_entry(id: '1'));
    LayerXLogStore.add(_entry(id: '2'));
    LayerXLogStore.add(_entry(id: '3'));

    expect(LayerXLogStore.logs.length, 2);
    expect(LayerXLogStore.logs.map((e) => e.id), ['3', '2']);
  });

  test('export contains the header and messages', () async {
    LayerXLogStore.add(_entry(id: '1', message: 'hello world'));
    final export = await LayerXLogStore.exportLogsAsString();
    expect(export, contains('LAYERX LOG EXPORT'));
    expect(export, contains('hello world'));
  });

  group('LayerXDuplicateGuard', () {
    test('finds a duplicate within the 2s window', () {
      final now = DateTime(2026, 1, 1, 12);
      LayerXLogStore.add(_entry(id: '1', at: now));
      final dup = LayerXDuplicateGuard.findDuplicate(
        'key',
        now.add(const Duration(seconds: 1)),
      );
      expect(dup, isNotNull);
    });

    test('ignores matches outside the window', () {
      final now = DateTime(2026, 1, 1, 12);
      LayerXLogStore.add(_entry(id: '1', at: now));
      final dup = LayerXDuplicateGuard.findDuplicate(
        'key',
        now.add(const Duration(seconds: 5)),
      );
      expect(dup, isNull);
    });
  });
}
