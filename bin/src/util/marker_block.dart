/// Idempotent, removable source edits delimited by sentinel comments.
///
/// Every change the setup CLI makes to user source is wrapped in a
/// `// layerx:begin(<id>) ... // layerx:end(<id>)` pair. Re-running setup can
/// then detect, replace, or skip a block deterministically — guaranteeing no
/// duplicate imports, registrations, or interceptors.
class MarkerBlock {
  MarkerBlock._();

  static String beginMarker(String id) =>
      '// layerx:begin($id) — managed by layerx_debugger, do not edit';

  static String endMarker(String id) => '// layerx:end($id)';

  /// Full block text: begin marker, inner lines, end marker.
  static String renderBlock(String id, List<String> inner) {
    final b = StringBuffer()..writeln(beginMarker(id));
    for (final l in inner) {
      b.writeln(l);
    }
    b.write(endMarker(id));
    return b.toString();
  }

  static bool has(String source, String id) =>
      source.contains(beginMarker(id));

  /// Replaces an existing block (markers + inner) with a freshly rendered one.
  /// Returns null if the block is absent.
  static String? replaceBlock(String source, String id, List<String> inner) {
    final begin = beginMarker(id);
    final start = source.indexOf(begin);
    if (start == -1) return null;
    final end = endMarker(id);
    final endIdx = source.indexOf(end, start);
    if (endIdx == -1) return null;
    return source.replaceRange(
        start, endIdx + end.length, renderBlock(id, inner));
  }

  /// Upserts a single `import:layerx` block holding [importLines].
  static String upsertImports(String source, List<String> importLines) {
    const id = 'import:layerx';
    if (has(source, id)) return replaceBlock(source, id, importLines)!;
    final block = renderBlock(id, importLines);
    final lines = source.split('\n');
    int lastImport = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('import ')) lastImport = i;
    }
    if (lastImport == -1) return '$block\n$source';
    lines.insert(lastImport + 1, block);
    return lines.join('\n');
  }
}
