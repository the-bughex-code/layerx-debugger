/// The kind of difference detected between two API responses for the same
/// endpoint.
enum LayerXSchemaDiffType {
  /// A key present in the current response but absent from the previous one.
  added,

  /// A key present in the previous response but absent from the current one.
  removed,

  /// A key whose Dart runtime type changed between responses.
  typeChanged,

  /// A key whose value changed between responses.
  valueChanged,
}

/// One field-level difference between two API responses for the same endpoint.
///
/// LayerX records these so the in-app viewer can highlight when a backend
/// silently changes its response shape.
class LayerXSchemaChange {
  /// The dotted JSON key path that changed, e.g. `data.user.role`.
  final String key;

  /// The kind of change that was detected.
  final LayerXSchemaDiffType diffType;

  /// The previous value, when available (for removals/changes).
  final String? previousValue;

  /// The current value, when available (for additions/changes).
  final String? currentValue;

  /// Creates a schema change entry.
  const LayerXSchemaChange({
    required this.key,
    required this.diffType,
    this.previousValue,
    this.currentValue,
  });

  /// A short uppercase label describing [diffType], e.g. `TYPE CHANGED`.
  String get label {
    switch (diffType) {
      case LayerXSchemaDiffType.added:
        return 'ADDED';
      case LayerXSchemaDiffType.removed:
        return 'REMOVED';
      case LayerXSchemaDiffType.typeChanged:
        return 'TYPE CHANGED';
      case LayerXSchemaDiffType.valueChanged:
        return 'VALUE CHANGED';
    }
  }
}
