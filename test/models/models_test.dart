import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  group('LayerXLogLevel', () {
    test('exposes a success level rendered in green', () {
      expect(LayerXLogLevel.values, contains(LayerXLogLevel.success));
      expect(LayerXLogLevel.success.color, const Color(0xFF43A047));
      expect(LayerXLogLevel.success.emoji, '✅');
      expect(LayerXLogLevel.success.label, 'SUCCESS');
    });

    test('aligns colors with the documented palette', () {
      expect(LayerXLogLevel.info.color, const Color(0xFF42A5F5)); // blue
      expect(LayerXLogLevel.warning.color, const Color(0xFFFFA726)); // amber
      expect(LayerXLogLevel.error.color, const Color(0xFFEF5350)); // red
    });

    test('only error-like levels have a tinted background', () {
      expect(LayerXLogLevel.debug.backgroundColor, isNull);
      expect(LayerXLogLevel.success.backgroundColor, isNotNull);
      expect(LayerXLogLevel.error.backgroundColor, isNotNull);
    });
  });

  group('LayerXJourneyStep', () {
    test('round-trips through JSON', () {
      final step = LayerXJourneyStep(
        timestamp: DateTime.parse('2026-06-16T10:00:00.000'),
        title: 'HomeView',
        description: 'Entered screen',
        type: 'ui',
      );

      final restored = LayerXJourneyStep.fromJson(step.toJson());

      expect(restored.timestamp, step.timestamp);
      expect(restored.title, 'HomeView');
      expect(restored.description, 'Entered screen');
      expect(restored.type, 'ui');
    });
  });

  group('LayerXLogEntry', () {
    LayerXLogEntry build() => LayerXLogEntry(
          id: '1',
          dedupKey: 'k',
          timestamp: DateTime(2026),
          level: LayerXLogLevel.info,
          source: LayerXLogSource.app,
          message: 'hello',
          journey: const [],
          extras: const {},
        );

    test('defaults occurrenceCount to 1 and seeds repeatTimestamps', () {
      final entry = build();
      expect(entry.occurrenceCount, 1);
      expect(entry.repeatTimestamps, [entry.timestamp]);
      expect(entry.responseChanged, isFalse);
      expect(entry.schemaChanges, isEmpty);
    });

    test('copyWith replaces only the provided fields', () {
      final entry = build();
      final copy = entry.copyWith(message: 'changed', statusCode: 404);

      expect(copy.message, 'changed');
      expect(copy.statusCode, 404);
      expect(copy.id, entry.id);
      expect(copy.level, entry.level);
    });
  });

  group('LayerXSchemaChange', () {
    test('labels match the diff type', () {
      const change = LayerXSchemaChange(
        key: 'data.role',
        diffType: LayerXSchemaDiffType.typeChanged,
      );
      expect(change.label, 'TYPE CHANGED');
    });
  });
}
