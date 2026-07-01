/// A parsed source location: a `package:` uri and a 1-based line number.
class LayerXStackLocation {
  /// The `package:` uri of the source file, or null when not parseable.
  final String? file;

  /// The 1-based line number within [file], or null when not parseable.
  final int? line;

  /// Creates a location from a [file] uri and [line] number.
  const LayerXStackLocation(this.file, this.line);

  /// A location with no file and no line.
  static const empty = LayerXStackLocation(null, null);

  /// Extracts the first meaningful `(package:…/file.dart:line:col)` frame from
  /// [trace]. Frames inside `layerx_debugger` are skipped. When [packageName]
  /// is given, only frames from that package are considered.
  static LayerXStackLocation parse(String trace, {String? packageName}) {
    final re = RegExp(r'\((package:[^\s:]+):(\d+):\d+\)');
    for (final line in trace.split('\n')) {
      final m = re.firstMatch(line);
      if (m == null) continue;
      final uri = m.group(1)!;
      if (uri.contains('package:layerx_debugger')) continue;
      if (packageName != null && !uri.contains('package:$packageName/')) {
        continue;
      }
      return LayerXStackLocation(uri, int.tryParse(m.group(2)!));
    }
    return empty;
  }
}
