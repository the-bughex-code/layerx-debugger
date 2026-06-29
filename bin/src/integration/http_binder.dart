import '../util/marker_block.dart';

const _dioImport = "import 'package:layerx_debugger/dio.dart';";
const _debuggerImport =
    "import 'package:layerx_debugger/layerx_debugger.dart';";

/// Wires `LayerXDioInterceptor` onto the first `Dio(...)` instantiation by
/// extending the initializer with a cascade:
///
///   final dio = Dio()..interceptors.add(LayerXDioInterceptor());
///
/// A cascade is appended to the `Dio(...)` expression itself rather than added
/// as a separate `dio.interceptors.add(...);` statement. The statement form is
/// only valid inside a function/constructor body; when the Dio lives in a
/// class-level field initializer (`static final Dio _dio = Dio();`) a trailing
/// statement lands in the class body, which is invalid Dart. The cascade is
/// valid in both positions, so this works wherever the client is constructed.
///
/// Returns null if no Dio() instantiation is found or it is already wired.
String? bindDio(String source) {
  if (MarkerBlock.has(source, 'dio-interceptor') ||
      source.contains('LayerXDioInterceptor')) {
    return null;
  }
  // Match the `Dio(...)` initializer up to (but not including) its `;`. The
  // greedy `[^;]*` consumes nested constructor args and balances back to the
  // closing paren, so `m.end` lands right after the outer `)`.
  final m = RegExp(r'=\s*Dio\([^;]*\)').firstMatch(source);
  if (m == null) return null;
  const cascade = '..interceptors.add(LayerXDioInterceptor())';
  var out = source.replaceRange(m.end, m.end, cascade);
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

final _clientCtorRe = RegExp(r'(=\s*)(IOClient|http\.Client|Client)(\s*\()');

/// Finds the index of the `)` that closes the `(` at [open].
int _matchParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Wraps the host app's underlying `http.Client`/`IOClient` field with
/// `LayerXHttpClient`, so every request the app makes through it is captured.
///
/// This is the robust, generic way to enable in-app API logs: because
/// `Client.get/post/put/patch/delete` and `MultipartRequest.send` all funnel
/// through `send`, wrapping the single client captures the whole API surface —
/// no per-call-site instrumentation, and it works whether or not the file has
/// any legacy interceptor calls. Returns null when no client construction is
/// found or it is already wrapped.
String? bindHttpClient(String source) {
  if (source.contains('LayerXHttpClient')) return null;
  final m = _clientCtorRe.firstMatch(source);
  if (m == null) return null;

  final openParen = m.end - 1; // index of the constructor's '('
  final close = _matchParen(source, openParen);
  if (close == -1) return null;

  final ctorNameStart = m.start + m.group(1)!.length; // start of the ctor name

  // Insert the extra closing paren first (higher index) so the earlier insert's
  // offset stays valid.
  var out = source.replaceRange(close + 1, close + 1, ')');
  out = out.replaceRange(ctorNameStart, ctorNameStart, 'LayerXHttpClient(');

  // Widen an explicit `IOClient`/`Client` field type to `http.Client` so the
  // wrapped client (a LayerXHttpClient) type-checks. Uses a mapped replace —
  // `String.replaceFirst` does not substitute `$1` capture references.
  out = out.replaceFirstMapped(
    RegExp(r'((?:late\s+)?final\s+)(?:IOClient|Client)(\s+\w+\s*=\s*LayerXHttpClient)'),
    (m) => '${m[1]}http.Client${m[2]}',
  );

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
