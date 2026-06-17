import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/utils/layerx_json_diff.dart';
import 'package:layerx_debugger/src/utils/layerx_solution_engine.dart';
import 'package:layerx_debugger/src/utils/layerx_source_detector.dart';

void main() {
  group('LayerXSourceDetector', () {
    test('classifies status codes', () {
      expect(
          LayerXSourceDetector.detect(statusCode: 500), LayerXLogSource.server);
      expect(LayerXSourceDetector.detect(statusCode: 404),
          LayerXLogSource.backend);
    });

    test('classifies network and app errors from text', () {
      expect(
        LayerXSourceDetector.detect(message: 'SocketException: failed'),
        LayerXLogSource.network,
      );
      expect(
        LayerXSourceDetector.detect(
            message: 'Null check operator used on a null value'),
        LayerXLogSource.app,
      );
    });

    test('falls back to unknown', () {
      expect(LayerXSourceDetector.detect(message: 'hello'),
          LayerXLogSource.unknown);
    });
  });

  group('LayerXSolutionEngine', () {
    test('suggests a fix for a known pattern', () {
      final suggestion = LayerXSolutionEngine.getSuggestion(
        'Null check operator used on a null value',
        null,
      );
      expect(suggestion, isNotNull);
      expect(suggestion, contains('null'));
    });

    test('flags 500 as a non-mobile bug', () {
      final suggestion = LayerXSolutionEngine.getSuggestion(
          'HTTP 500 Internal Server Error', null);
      expect(suggestion, contains('NOT a mobile bug'));
    });

    test('returns null when nothing matches', () {
      expect(LayerXSolutionEngine.getSuggestion('all good', null), isNull);
    });
  });

  group('LayerXJsonDiff', () {
    test('normalises endpoint keys', () {
      expect(
          LayerXJsonDiff.normaliseEndpointKey('/user/123?x=1'), '/user/{id}');
    });

    test('detects added, removed, type and value changes', () {
      expect(
        LayerXJsonDiff.diff('{"a":1}', '{"a":2}').single.diffType,
        LayerXSchemaDiffType.valueChanged,
      );
      expect(
        LayerXJsonDiff.diff('{"a":1}', '{"a":1,"b":2}').single.diffType,
        LayerXSchemaDiffType.added,
      );
      expect(
        LayerXJsonDiff.diff('{"a":1,"b":2}', '{"a":1}').single.diffType,
        LayerXSchemaDiffType.removed,
      );
      expect(
        LayerXJsonDiff.diff('{"a":1}', '{"a":"1"}').single.diffType,
        LayerXSchemaDiffType.typeChanged,
      );
    });

    test('handles non-JSON payloads as a raw change', () {
      final changes = LayerXJsonDiff.diff('not json', 'also not json');
      expect(changes.single.key, '(raw body)');
    });
  });

  group('LayerXBlameEngine', () {
    test('returns null for non-actionable levels', () {
      final info = LayerXBlameEngine.analyze(
        LayerXLogEntry(
          id: '1',
          dedupKey: 'k',
          timestamp: DateTime(2026),
          level: LayerXLogLevel.info,
          source: LayerXLogSource.app,
          message: 'fine',
          journey: const [],
          extras: const {},
        ),
      );
      expect(info, isNull);
    });

    test('blames the backend for a 500', () {
      final info = LayerXBlameEngine.analyze(
        LayerXLogEntry(
          id: '1',
          dedupKey: 'k',
          timestamp: DateTime(2026),
          level: LayerXLogLevel.error,
          source: LayerXLogSource.server,
          message: 'boom',
          statusCode: 500,
          journey: const [],
          extras: const {},
        ),
      );
      expect(info, isNotNull);
      expect(info!.responsibleParty, contains('Backend'));
    });
  });
}
