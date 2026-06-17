import 'dart:convert';

/// Masks sensitive values (passwords, tokens, …) before they are logged.
///
/// Matching is case-insensitive on the key name. The built-in keys are
/// `password`, `token`, `authorization`, `apiKey` and `secret`; callers can
/// supply additional keys via [LayerXDebugConfig.maskKeys].
class LayerXMasker {
  LayerXMasker._();

  /// The built-in sensitive key names (compared case-insensitively).
  static const List<String> defaultKeys = [
    'password',
    'token',
    'authorization',
    'apikey',
    'secret',
  ];

  /// The replacement written in place of a masked value.
  static const String maskValue = '********';

  /// Recursively masks sensitive values in a decoded JSON structure (maps,
  /// lists and scalars). Returns a new structure; the input is not mutated.
  static dynamic mask(dynamic data, {List<String>? extraKeys}) =>
      _mask(data, _resolveKeys(extraKeys));

  /// Masks sensitive values inside a raw JSON [raw] string.
  ///
  /// On success returns indented, masked JSON. If [raw] is not valid JSON it is
  /// returned unchanged.
  static String maskJsonString(String raw, {List<String>? extraKeys}) {
    try {
      final decoded = json.decode(raw);
      final masked = mask(decoded, extraKeys: extraKeys);
      return const JsonEncoder.withIndent('  ').convert(masked);
    } catch (_) {
      return raw;
    }
  }

  /// Returns a copy of [headers] with sensitive header values masked.
  static Map<String, String> maskHeaders(
    Map<String, String> headers, {
    List<String>? extraKeys,
  }) {
    final keys = _resolveKeys(extraKeys);
    return headers.map(
      (key, value) => keys.contains(key.toLowerCase())
          ? MapEntry(key, maskValue)
          : MapEntry(key, value),
    );
  }

  static List<String> _resolveKeys(List<String>? extraKeys) => [
        ...defaultKeys,
        if (extraKeys != null) ...extraKeys.map((k) => k.toLowerCase()),
      ];

  static dynamic _mask(dynamic data, List<String> keys) {
    if (data is Map) {
      return data.map((key, value) {
        if (keys.contains(key.toString().toLowerCase())) {
          return MapEntry(key, maskValue);
        }
        return MapEntry(key, _mask(value, keys));
      });
    }
    if (data is List) {
      return data.map((value) => _mask(value, keys)).toList();
    }
    return data;
  }
}
