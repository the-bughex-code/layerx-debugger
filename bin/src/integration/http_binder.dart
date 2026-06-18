import '../util/marker_block.dart';

const _dioImport = "import 'package:layerx_debugger/dio.dart';";
const _debuggerImport =
    "import 'package:layerx_debugger/layerx_debugger.dart';";

/// Inserts `LayerXDioInterceptor` after the first `Dio(...)` instantiation.
/// Returns null if no Dio() instantiation is found or it is already wired.
String? bindDio(String source) {
  if (MarkerBlock.has(source, 'dio-interceptor') ||
      source.contains('LayerXDioInterceptor')) {
    return null;
  }
  final m = RegExp(r'(\w+)\s*=\s*Dio\([^;]*\)\s*;').firstMatch(source);
  if (m == null) return null;
  final varName = m.group(1)!;
  final block = MarkerBlock.renderBlock('dio-interceptor', [
    '  $varName.interceptors.add(LayerXDioInterceptor());',
  ]);
  var out = source.replaceRange(m.end, m.end, '\n$block');
  if (!out.contains(_dioImport)) {
    out = MarkerBlock.upsertImports(out, [_dioImport]);
  }
  return out;
}

final _legacyRecordRe = RegExp(
  r'LxHttpInterceptor\.record\s*\(\s*'
  r'endpoint:\s*([^,]+),\s*'
  r'method:\s*([^,]+),\s*'
  r'response:\s*(\w+)\s*,\s*'
  r'requestBody:\s*([^,]+),\s*'
  r'durationMs:\s*([^,\)]+),?\s*\)\s*;',
  dotAll: true,
);

/// Rewrites legacy `LxHttpInterceptor.record(...)` calls to
/// `LayerXNetworkLogger.record(...)`. Returns null if none are present.
String? bindHttpLegacy(String source) {
  if (!source.contains('LxHttpInterceptor.record')) return null;
  var out = source.replaceAllMapped(_legacyRecordRe, (m) {
    final ep = m.group(1)!.trim();
    final met = m.group(2)!.trim();
    final resp = m.group(3)!.trim();
    final reqB = m.group(4)!.trim();
    final dur = m.group(5)!.trim();
    final inner = [
      '    LayerXNetworkLogger.record(',
      '      endpoint: $ep,',
      '      method: $met,',
      '      statusCode: $resp.statusCode,',
      '      responseBody: $resp.body,',
      '      requestBody: $reqB,',
      '      responseHeaders: $resp.headers,',
      '      durationMs: $dur,',
      '    );',
    ];
    return MarkerBlock.renderBlock('http-record', inner);
  });
  if (!out.contains(_debuggerImport)) {
    out = MarkerBlock.upsertImports(out, [_debuggerImport]);
  }
  return out;
}

/// The copy-paste snippet shown when http auto-injection isn't possible.
const httpGuidedSnippet = '''
LayerXNetworkLogger.record(
  endpoint: <url>,
  method: <METHOD>,
  statusCode: response.statusCode,
  responseBody: response.body,
  requestBody: <requestBodyString>,
  responseHeaders: response.headers,
  durationMs: <elapsedMs>,
);''';
