import 'dart:convert';

import '../models/layerx_schema_change.dart';

/// Computes field-level differences between two JSON payloads.
///
/// Used by the log store to detect when a backend changes the shape of its
/// response for the same endpoint between two calls.
class LayerXJsonDiff {
  LayerXJsonDiff._();

  /// Normalises an endpoint URL so repeated calls to a parameterised route are
  /// tracked as the same endpoint.
  ///
  /// Strips the query string and replaces numeric path segments with `{id}`,
  /// e.g. `/user/123?x=1` becomes `/user/{id}`.
  static String normaliseEndpointKey(String endpoint) {
    final noQuery = endpoint.split('?').first;
    return noQuery.replaceAllMapped(RegExp(r'/\d+'), (_) => '/{id}');
  }

  /// Computes a field-level diff between two raw JSON strings.
  ///
  /// Returns at most 30 changes to keep the diff readable. Non-JSON payloads
  /// are reported as a single raw value change.
  static List<LayerXSchemaChange> diff(String previous, String current) {
    final changes = <LayerXSchemaChange>[];

    dynamic prevJson;
    dynamic currJson;
    try {
      prevJson = json.decode(previous);
      currJson = json.decode(current);
    } catch (_) {
      if (previous != current) {
        changes.add(LayerXSchemaChange(
          key: '(raw body)',
          diffType: LayerXSchemaDiffType.valueChanged,
          previousValue: _truncate(previous, maxLen: 80),
          currentValue: _truncate(current, maxLen: 80),
        ));
      }
      return changes;
    }

    final prevFlat = _flatten(prevJson);
    final currFlat = _flatten(currJson);
    final allKeys = <String>{...prevFlat.keys, ...currFlat.keys};

    for (final key in allKeys) {
      if (changes.length >= 30) break;

      final prevVal = prevFlat[key];
      final currVal = currFlat[key];

      if (!prevFlat.containsKey(key)) {
        changes.add(LayerXSchemaChange(
          key: key,
          diffType: LayerXSchemaDiffType.added,
          currentValue: _truncate(currVal.toString()),
        ));
      } else if (!currFlat.containsKey(key)) {
        changes.add(LayerXSchemaChange(
          key: key,
          diffType: LayerXSchemaDiffType.removed,
          previousValue: _truncate(prevVal.toString()),
        ));
      } else if (prevVal.runtimeType != currVal.runtimeType) {
        changes.add(LayerXSchemaChange(
          key: key,
          diffType: LayerXSchemaDiffType.typeChanged,
          previousValue:
              '${prevVal.runtimeType}: ${_truncate(prevVal.toString())}',
          currentValue:
              '${currVal.runtimeType}: ${_truncate(currVal.toString())}',
        ));
      } else if (prevVal.toString() != currVal.toString()) {
        changes.add(LayerXSchemaChange(
          key: key,
          diffType: LayerXSchemaDiffType.valueChanged,
          previousValue: _truncate(prevVal.toString()),
          currentValue: _truncate(currVal.toString()),
        ));
      }
    }

    return changes;
  }

  /// Flattens [value] into dot-notation key paths.
  ///
  /// e.g. `{"data": {"user": {"id": 1}}}` becomes `{"data.user.id": 1}`.
  static Map<String, dynamic> _flatten(
    dynamic value, {
    String prefix = '',
    int depth = 0,
  }) {
    final result = <String, dynamic>{};

    if (depth > 8) {
      result[prefix] = value.toString();
      return result;
    }

    if (value is Map<String, dynamic>) {
      value.forEach((key, val) {
        final fullKey = prefix.isEmpty ? key : '$prefix.$key';
        result.addAll(_flatten(val, prefix: fullKey, depth: depth + 1));
      });
    } else if (value is List) {
      final arrayKey = prefix.isEmpty ? '[]' : prefix;
      result['$arrayKey[length]'] = value.length;
      if (value.isNotEmpty) {
        result.addAll(
            _flatten(value.first, prefix: '$arrayKey[0]', depth: depth + 1));
      }
    } else {
      result[prefix] = value;
    }

    return result;
  }

  static String _truncate(String s, {int maxLen = 60}) =>
      s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}
