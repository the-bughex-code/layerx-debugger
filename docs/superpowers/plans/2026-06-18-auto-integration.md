# Subsystem A — Auto-Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the LayerX setup CLI so it detects logger/HTTP services by content, injects all changes inside removable marker blocks (idempotent re-runs), aborts if no logger exists, skips HTTP gracefully, supports dio + http, and verifies the result.

**Architecture:** Pure string-transformation functions (marker editing, logger/http patching) are separated from file I/O and console printing so they can be unit-tested directly. A new `IntegrationScanner` produces a typed targets report. Steps (`LoggerBindStep`, `HttpBindStep`, `VerifyStep`) wrap the pure functions with I/O. A new `LayerXDioInterceptor` ships behind `package:layerx_debugger/dio.dart`.

**Tech Stack:** Dart (CLI in `bin/`), `package:test` / `flutter_test`, `logger`, `http`, `dio` (isolated entrypoint).

---

## File Structure

- `bin/src/util/marker_block.dart` — NEW: marker rendering + idempotent block upsert/replace (pure).
- `bin/src/integration/integration_targets.dart` — NEW: typed detection result data classes (pure).
- `bin/src/integration/integration_scanner.dart` — NEW: scans `lib/app` for logger/dio/http targets.
- `bin/src/integration/logger_binder.dart` — NEW: pure `bindLogger(String) -> String?`.
- `bin/src/integration/http_binder.dart` — NEW: pure `bindDio` / `bindHttp` functions.
- `bin/src/steps/logger_bind_step.dart` — NEW: file I/O wrapper around `logger_binder`.
- `bin/src/steps/http_bind_step.dart` — NEW: file I/O wrapper around `http_binder` (dio + http).
- `bin/src/steps/verify_step.dart` — NEW: `dart format` touched files + `flutter analyze` report.
- `bin/src/steps/service_logger_http_step.dart` — DELETE after split.
- `bin/setup.dart` — MODIFY: wire new steps + scanner.
- `bin/src/steps/pubspec_step.dart` — MODIFY: resolve published version instead of hardcoded `^1.0.2`.
- `lib/src/services/network/layerx_dio_interceptor.dart` — NEW: `dio.Interceptor` runtime artifact.
- `lib/dio.dart` — NEW: opt-in entrypoint exporting the dio interceptor.
- `pubspec.yaml` — MODIFY: add `dio` dependency.
- `test/setup/marker_block_test.dart`, `test/setup/logger_binder_test.dart`, `test/setup/http_binder_test.dart`, `test/setup/integration_scanner_test.dart` — NEW tests.

---

## Task 1: MarkerBlock primitive

**Files:**
- Create: `bin/src/util/marker_block.dart`
- Test: `test/setup/marker_block_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:test/test.dart';
import '../../bin/src/util/marker_block.dart';

void main() {
  group('MarkerBlock', () {
    test('renderBlock wraps inner lines in begin/end markers', () {
      final out = MarkerBlock.renderBlock('x', ['a();', 'b();']);
      expect(out, contains('// layerx:begin(x)'));
      expect(out, contains('// layerx:end(x)'));
      expect(out, contains('a();'));
      expect(out, contains('b();'));
    });

    test('has detects an existing block', () {
      final src = MarkerBlock.renderBlock('x', ['a();']);
      expect(MarkerBlock.has(src, 'x'), isTrue);
      expect(MarkerBlock.has(src, 'y'), isFalse);
    });

    test('replaceBlock swaps inner content, leaving one block', () {
      final src = 'top\n${MarkerBlock.renderBlock('x', ['old();'])}\nbottom';
      final out = MarkerBlock.replaceBlock(src, 'x', ['new();'])!;
      expect(out, contains('new();'));
      expect(out, isNot(contains('old();')));
      expect('// layerx:begin(x)'.allMatches(out).length, 1);
    });

    test('replaceBlock returns null when block absent', () {
      expect(MarkerBlock.replaceBlock('nothing', 'x', ['a();']), isNull);
    });

    test('upsertImports inserts after last import, idempotent', () {
      const src = "import 'a.dart';\nimport 'b.dart';\n\nclass C {}";
      final once = MarkerBlock.upsertImports(src, ["import 'p.dart';"]);
      final twice = MarkerBlock.upsertImports(once, ["import 'p.dart';"]);
      expect(once, contains("import 'p.dart';"));
      expect(twice, equals(once));
      expect('// layerx:begin(import:layerx)'.allMatches(twice).length, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/setup/marker_block_test.dart`
Expected: FAIL — `marker_block.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// bin/src/util/marker_block.dart
/// Idempotent, removable source edits delimited by sentinel comments.
class MarkerBlock {
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
    return source.replaceRange(start, endIdx + end.length, renderBlock(id, inner));
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/setup/marker_block_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add bin/src/util/marker_block.dart test/setup/marker_block_test.dart
git commit -m "feat(setup): add MarkerBlock idempotent source-edit primitive"
```

---

## Task 2: Integration targets model + scanner

**Files:**
- Create: `bin/src/integration/integration_targets.dart`
- Create: `bin/src/integration/integration_scanner.dart`
- Test: `test/setup/integration_scanner_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:test/test.dart';
import '../../bin/src/integration/integration_scanner.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lx_scan'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(String rel, String content) {
    final f = File('${tmp.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  test('detects logger by static final Logger field', () {
    write('lib/app/services/logger_service.dart',
        'class LoggerService { static final Logger _l = Logger(); }');
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.logger.found, isTrue);
    expect(t.logger.className, 'LoggerService');
  });

  test('detects dio instantiation and http wrapper', () {
    write('lib/app/services/net.dart', "var d = Dio();");
    write('lib/app/services/https_calls.dart',
        "import 'package:http/http.dart' as http;\nclass HttpsCalls { http.get(); }");
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.dio.found, isTrue);
    expect(t.httpWrap.found, isTrue);
    expect(t.httpWrap.className, 'HttpsCalls');
  });

  test('reports notFound when nothing matches', () {
    write('lib/app/services/empty.dart', 'class Empty {}');
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.logger.found, isFalse);
    expect(t.dio.found, isFalse);
    expect(t.httpWrap.found, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/setup/integration_scanner_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// bin/src/integration/integration_targets.dart
class LoggerTarget {
  final bool found;
  final String? filePath;
  final String? className;
  const LoggerTarget._(this.found, this.filePath, this.className);
  const LoggerTarget.notFound() : this._(false, null, null);
  const LoggerTarget.at(String path, String name) : this._(true, path, name);
}

class DioTarget {
  final bool found;
  final String? filePath;
  const DioTarget._(this.found, this.filePath);
  const DioTarget.notFound() : this._(false, null);
  const DioTarget.at(String path) : this._(true, path);
}

class HttpWrapTarget {
  final bool found;
  final String? filePath;
  final String? className;
  const HttpWrapTarget._(this.found, this.filePath, this.className);
  const HttpWrapTarget.notFound() : this._(false, null, null);
  const HttpWrapTarget.at(String path, String name) : this._(true, path, name);
}

class IntegrationTargets {
  final LoggerTarget logger;
  final DioTarget dio;
  final HttpWrapTarget httpWrap;
  const IntegrationTargets({
    required this.logger,
    required this.dio,
    required this.httpWrap,
  });
  bool get anyHttp => dio.found || httpWrap.found;
}
```

```dart
// bin/src/integration/integration_scanner.dart
import 'dart:io';
import 'integration_targets.dart';

class IntegrationScanner {
  final String projectRoot;
  IntegrationScanner(this.projectRoot);

  static final _loggerRe =
      RegExp(r'static\s+final\s+Logger\s+\w+\s*=\s*Logger\(');
  static final _classRe = RegExp(r'class\s+(\w+)');
  static final _dioRe = RegExp(r'\bDio\s*\(');
  static final _httpNameRe =
      RegExp(r'class\s+(\w*(?:Http|Api|Network)\w*|HttpsCalls)\b');

  IntegrationTargets scan() {
    LoggerTarget logger = const LoggerTarget.notFound();
    DioTarget dio = const DioTarget.notFound();
    HttpWrapTarget httpWrap = const HttpWrapTarget.notFound();

    final appDir = Directory('$projectRoot/lib/app');
    if (!appDir.existsSync()) {
      return IntegrationTargets(logger: logger, dio: dio, httpWrap: httpWrap);
    }

    final dartFiles = appDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in dartFiles) {
      final src = f.readAsStringSync();
      if (!logger.found && _loggerRe.hasMatch(src)) {
        final name = _classRe.firstMatch(src)?.group(1) ?? 'LoggerService';
        logger = LoggerTarget.at(f.path, name);
      }
      if (!dio.found && _dioRe.hasMatch(src)) {
        dio = DioTarget.at(f.path);
      }
      if (!httpWrap.found &&
          src.contains("package:http/http.dart") &&
          _httpNameRe.hasMatch(src)) {
        final name = _httpNameRe.firstMatch(src)!.group(1)!;
        httpWrap = HttpWrapTarget.at(f.path, name);
      }
    }
    return IntegrationTargets(logger: logger, dio: dio, httpWrap: httpWrap);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/setup/integration_scanner_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add bin/src/integration/integration_targets.dart bin/src/integration/integration_scanner.dart test/setup/integration_scanner_test.dart
git commit -m "feat(setup): add content-based integration target scanner"
```

---

## Task 3: Logger binder (pure transformation)

**Files:**
- Create: `bin/src/integration/logger_binder.dart`
- Test: `test/setup/logger_binder_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:test/test.dart';
import '../../bin/src/integration/logger_binder.dart';

const _consoleOutput = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    level: Level.trace,
    output: ConsoleOutput(),
  );
}
''';

void main() {
  test('injects LayerXLogInterceptorOutput into ConsoleOutput-only logger', () {
    final out = bindLogger(_consoleOutput)!;
    expect(out, contains('LayerXLogInterceptorOutput()'));
    expect(out, contains('MultiOutput('));
    expect(out, contains("package:layerx_debugger/layerx_debugger.dart"));
  });

  test('is idempotent — second run returns null (already bound)', () {
    final once = bindLogger(_consoleOutput)!;
    expect(bindLogger(once), isNull);
  });

  test('returns null for a non-logger file', () {
    expect(bindLogger('class Foo {}'), isNull);
  });

  test('replaces legacy LxLogOutput with LayerXLogInterceptorOutput', () {
    const legacy = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    output: MultiOutput([ConsoleOutput(), LxLogOutput()]),
  );
}
''';
    final out = bindLogger(legacy)!;
    expect(out, contains('LayerXLogInterceptorOutput()'));
    expect(out, isNot(contains('LxLogOutput()')));
  });

  test('adds output param when none exists', () {
    const noOutput = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(
    level: Level.trace,
  );
}
''';
    final out = bindLogger(noOutput)!;
    expect(out, contains('output:'));
    expect(out, contains('LayerXLogInterceptorOutput()'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/setup/logger_binder_test.dart`
Expected: FAIL — `logger_binder.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// bin/src/integration/logger_binder.dart
import '../util/marker_block.dart';

const _debuggerImport =
    "import 'package:layerx_debugger/layerx_debugger.dart';";
final _loggerCtorRe = RegExp(r'static\s+final\s+Logger\s+\w+\s*=\s*Logger\(');

/// Binds [LayerXLogInterceptorOutput] into a `logger`-package Logger.
/// Returns the patched source, or null if not a logger file / already bound.
String? bindLogger(String source) {
  if (!_loggerCtorRe.hasMatch(source)) return null;
  if (source.contains('LayerXLogInterceptorOutput')) return null;

  var out = source;

  // 1. Legacy LxLogOutput() -> our output.
  if (out.contains('LxLogOutput()')) {
    out = out.replaceAll('LxLogOutput()', 'LayerXLogInterceptorOutput()');
  } else if (RegExp(r'output:\s*ConsoleOutput\(\)').hasMatch(out)) {
    // 2. output: ConsoleOutput() -> MultiOutput([...])
    out = out.replaceFirst(
      RegExp(r'output:\s*ConsoleOutput\(\)'),
      'output: MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()])',
    );
  } else if (RegExp(r'MultiOutput\(\s*\[').hasMatch(out) &&
      out.contains('ConsoleOutput()')) {
    // 3. existing MultiOutput without our output -> append.
    out = out.replaceFirst(
      'ConsoleOutput()',
      'ConsoleOutput(), LayerXLogInterceptorOutput()',
    );
  } else {
    // 4. No output: param — insert a marker-wrapped one before the ctor's ).
    final m = _loggerCtorRe.firstMatch(out)!;
    // find matching close paren for the Logger( call
    var depth = 0;
    var close = -1;
    for (var i = m.end - 1; i < out.length; i++) {
      final ch = out[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) {
          close = i;
          break;
        }
      }
    }
    if (close == -1) return null;
    final block = MarkerBlock.renderBlock('logger-output', [
      '    output: MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()]),',
    ]);
    out = '${out.substring(0, close)}$block\n  ${out.substring(close)}';
  }

  // Ensure the package import exists (own marker block).
  if (!out.contains(_debuggerImport)) {
    out = MarkerBlock.upsertImports(out, [_debuggerImport]);
  }
  // Safety: collapse any accidental double commas.
  out = out.replaceAll(RegExp(r',(\s*),'), r',$1');
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/setup/logger_binder_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add bin/src/integration/logger_binder.dart test/setup/logger_binder_test.dart
git commit -m "feat(setup): add idempotent logger binder"
```

---

## Task 4: HTTP binder (dio + http, pure)

**Files:**
- Create: `bin/src/integration/http_binder.dart`
- Test: `test/setup/http_binder_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:test/test.dart';
import '../../bin/src/integration/http_binder.dart';

void main() {
  group('bindDio', () {
    const dioSrc = '''
class Net {
  final dio = Dio();
}
''';
    test('adds interceptor after Dio() and dio.dart import', () {
      final out = bindDio(dioSrc)!;
      expect(out, contains('LayerXDioInterceptor()'));
      expect(out, contains('interceptors.add'));
      expect(out, contains("package:layerx_debugger/dio.dart"));
    });
    test('idempotent', () {
      final once = bindDio(dioSrc)!;
      expect(bindDio(once), isNull);
    });
    test('null when no Dio()', () => expect(bindDio('class X {}'), isNull));
  });

  group('bindHttpLegacy', () {
    const legacy = '''
class HttpsCalls {
  void f(r, body) {
    LxHttpInterceptor.record(
      endpoint: ep,
      method: m,
      response: r,
      requestBody: body,
      durationMs: 10,
    );
  }
}
''';
    test('rewrites LxHttpInterceptor.record to LayerXNetworkLogger.record', () {
      final out = bindHttpLegacy(legacy)!;
      expect(out, contains('LayerXNetworkLogger.record('));
      expect(out, contains('statusCode: r.statusCode'));
      expect(out, contains('responseBody: r.body'));
      expect(out, isNot(contains('LxHttpInterceptor')));
    });
    test('null when no legacy call', () =>
        expect(bindHttpLegacy('class X {}'), isNull));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/setup/http_binder_test.dart`
Expected: FAIL — `http_binder.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// bin/src/integration/http_binder.dart
import '../util/marker_block.dart';

const _dioImport = "import 'package:layerx_debugger/dio.dart';";
const _debuggerImport =
    "import 'package:layerx_debugger/layerx_debugger.dart';";

/// Inserts `LayerXDioInterceptor` after the first `Dio(...)` instantiation.
/// Returns null if no Dio() or already wired.
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
/// `LayerXNetworkLogger.record(...)`. Returns null if none present.
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/setup/http_binder_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add bin/src/integration/http_binder.dart test/setup/http_binder_test.dart
git commit -m "feat(setup): add idempotent dio + http binders"
```

---

## Task 5: LayerXDioInterceptor runtime artifact + dio entrypoint

**Files:**
- Modify: `pubspec.yaml` (add `dio`)
- Create: `lib/src/services/network/layerx_dio_interceptor.dart`
- Create: `lib/dio.dart`

- [ ] **Step 1: Add dio to pubspec dependencies**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  dio: ^5.7.0
```

Run: `flutter pub get`
Expected: resolves successfully.

- [ ] **Step 2: Write the interceptor**

```dart
// lib/src/services/network/layerx_dio_interceptor.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:layerx_debugger/src/services/network/layerx_network_logger.dart';

/// A Dio [Interceptor] that forwards responses and errors to LayerX.
class LayerXDioInterceptor extends Interceptor {
  final _starts = <int, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _starts[options.hashCode] = DateTime.now();
    handler.next(options);
  }

  int _elapsed(RequestOptions o) {
    final start = _starts.remove(o.hashCode);
    return start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
  }

  String? _stringify(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    LayerXNetworkLogger.record(
      endpoint: o.uri.toString(),
      method: o.method,
      statusCode: response.statusCode ?? 0,
      responseBody: _stringify(response.data),
      requestBody: _stringify(o.data),
      requestHeaders: o.headers.map((k, v) => MapEntry(k, '$v')),
      responseHeaders:
          response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      durationMs: _elapsed(o),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final resp = err.response;
    if (resp != null) {
      LayerXNetworkLogger.record(
        endpoint: o.uri.toString(),
        method: o.method,
        statusCode: resp.statusCode ?? 0,
        responseBody: _stringify(resp.data),
        requestBody: _stringify(o.data),
        durationMs: _elapsed(o),
      );
    } else {
      LayerXNetworkLogger.recordException(
        endpoint: o.uri.toString(),
        method: o.method,
        error: err,
        stackTrace: err.stackTrace,
        requestBody: _stringify(o.data),
        durationMs: _elapsed(o),
      );
    }
    handler.next(err);
  }
}
```

- [ ] **Step 3: Write the opt-in entrypoint**

```dart
// lib/dio.dart
/// Opt-in Dio integration for LayerX Debugger.
///
/// ```dart
/// import 'package:layerx_debugger/dio.dart';
/// dio.interceptors.add(LayerXDioInterceptor());
/// ```
library;

export 'src/services/network/layerx_dio_interceptor.dart';
```

- [ ] **Step 4: Verify it analyzes**

Run: `flutter analyze lib/src/services/network/layerx_dio_interceptor.dart lib/dio.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/src/services/network/layerx_dio_interceptor.dart lib/dio.dart pubspec.lock
git commit -m "feat: add LayerXDioInterceptor behind opt-in package:layerx_debugger/dio.dart"
```

---

## Task 6: LoggerBindStep + HttpBindStep (file I/O wrappers)

**Files:**
- Create: `bin/src/steps/logger_bind_step.dart`
- Create: `bin/src/steps/http_bind_step.dart`

- [ ] **Step 1: Write LoggerBindStep**

```dart
// bin/src/steps/logger_bind_step.dart
import 'dart:io';
import '../integration/integration_targets.dart';
import '../integration/logger_binder.dart';
import '../utils/cli_printer.dart';

class LoggerBindStep {
  final LoggerTarget target;
  LoggerBindStep(this.target);

  /// Returns true if logging was bound (or already bound). Aborts the process
  /// if no logger exists — logs cannot be captured without it.
  bool run() {
    CliPrinter.step('Binding LoggerService ...');
    if (!target.found) {
      CliPrinter.error(
        'LayerX LoggerService was not found. Integration cannot continue '
        'because logs will not be captured.',
      );
      exit(1);
    }
    final file = File(target.filePath!);
    final src = file.readAsStringSync();
    final patched = bindLogger(src);
    if (patched == null) {
      CliPrinter.skip('${target.className} already bound — no changes.');
      return true;
    }
    final bak = File('${file.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(src);
    file.writeAsStringSync(patched);
    CliPrinter.success('${target.className} bound with LayerXLogInterceptorOutput.');
    return true;
  }
}
```

- [ ] **Step 2: Write HttpBindStep**

```dart
// bin/src/steps/http_bind_step.dart
import 'dart:io';
import '../integration/integration_targets.dart';
import '../integration/http_binder.dart';
import '../utils/cli_printer.dart';

class HttpBindStep {
  final IntegrationTargets targets;
  HttpBindStep(this.targets);

  /// Returns true if any HTTP integration was applied.
  bool run() {
    CliPrinter.step('Binding HTTP layer ...');
    if (!targets.anyHttp) {
      CliPrinter.info(
        'No HTTP/dio service detected — network interception skipped. '
        'Add an HttpService or Dio client and re-run setup to enable it.',
      );
      return false;
    }
    var changed = false;

    if (targets.dio.found) {
      changed = _patch(targets.dio.filePath!, bindDio,
              'Dio client bound with LayerXDioInterceptor.') ||
          changed;
    }
    if (targets.httpWrap.found) {
      final applied = _patch(targets.httpWrap.filePath!, bindHttpLegacy,
          '${targets.httpWrap.className} bound with LayerXNetworkLogger.');
      if (!applied) {
        CliPrinter.warning(
          'Could not auto-inject into ${targets.httpWrap.className}. '
          'Add this at your response site:\n$httpGuidedSnippet',
        );
      }
      changed = applied || changed;
    }
    return changed;
  }

  bool _patch(String path, String? Function(String) binder, String okMsg) {
    final file = File(path);
    final src = file.readAsStringSync();
    final patched = binder(src);
    if (patched == null) return false;
    final bak = File('${file.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(src);
    file.writeAsStringSync(patched);
    CliPrinter.success(okMsg);
    return true;
  }
}
```

- [ ] **Step 3: Verify analysis**

Run: `dart analyze bin/src/steps/logger_bind_step.dart bin/src/steps/http_bind_step.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add bin/src/steps/logger_bind_step.dart bin/src/steps/http_bind_step.dart
git commit -m "feat(setup): add LoggerBindStep and HttpBindStep I/O wrappers"
```

---

## Task 7: VerifyStep (format + analyze report)

**Files:**
- Create: `bin/src/steps/verify_step.dart`

- [ ] **Step 1: Write VerifyStep**

```dart
// bin/src/steps/verify_step.dart
import 'dart:io';
import '../utils/cli_printer.dart';

class VerifyStep {
  final String projectRoot;
  final List<String> touchedFiles;
  VerifyStep(this.projectRoot, this.touchedFiles);

  Future<void> run() async {
    CliPrinter.step('Verifying changes ...');
    final existing = touchedFiles.where((p) => File(p).existsSync()).toList();
    if (existing.isNotEmpty) {
      await Process.run('dart', ['format', ...existing],
          workingDirectory: projectRoot);
      CliPrinter.success('Formatted ${existing.length} file(s).');
    }
    final analyze = await Process.run('flutter', ['analyze'],
        workingDirectory: projectRoot);
    if (analyze.exitCode == 0) {
      CliPrinter.success('flutter analyze passed — no issues.');
    } else {
      CliPrinter.warning(
        'flutter analyze reported issues (setup still completed). Review:\n'
        '${analyze.stdout}',
      );
    }
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `dart analyze bin/src/steps/verify_step.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add bin/src/steps/verify_step.dart
git commit -m "feat(setup): add VerifyStep (format touched files + analyze report)"
```

---

## Task 8: Resolve published version in PubspecStep

**Files:**
- Modify: `bin/src/steps/pubspec_step.dart`

- [ ] **Step 1: Replace the hardcoded version**

In `pubspec_step.dart`, replace the hardcoded insertion:

```dart
    final insertAt = depIndex + marker.length;
    content =
        '${content.substring(0, insertAt)}\n'
        '  layerx_debugger: ^1.0.2'
        '${content.substring(insertAt)}';
```

with a version read from the package's own pubspec (the CLI ships with the package, so `Platform.script` resolves the package root):

```dart
    final version = _resolvePackageVersion();
    final insertAt = depIndex + marker.length;
    content =
        '${content.substring(0, insertAt)}\n'
        '  layerx_debugger: ^$version'
        '${content.substring(insertAt)}';
```

Add this helper method to the class:

```dart
  String _resolvePackageVersion() {
    try {
      // bin/src/steps/pubspec_step.dart -> package root is 3 levels up from bin/.
      final scriptPath = Platform.script.toFilePath();
      var dir = File(scriptPath).parent;
      for (var i = 0; i < 6; i++) {
        final p = File('${dir.path}/pubspec.yaml');
        if (p.existsSync() &&
            p.readAsStringSync().contains('name: layerx_debugger')) {
          final m = RegExp(r'^version:\s*(.+)$', multiLine: true)
              .firstMatch(p.readAsStringSync());
          if (m != null) return m.group(1)!.trim();
        }
        dir = dir.parent;
      }
    } catch (_) {}
    return '1.0.6'; // fallback to last known version
  }
```

Also update the success message string from `^1.0.2` to `^$version`.

- [ ] **Step 2: Verify analysis**

Run: `dart analyze bin/src/steps/pubspec_step.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add bin/src/steps/pubspec_step.dart
git commit -m "fix(setup): resolve real package version instead of hardcoded ^1.0.2"
```

---

## Task 9: Wire setup.dart to new steps; delete old step

**Files:**
- Modify: `bin/setup.dart`
- Delete: `bin/src/steps/service_logger_http_step.dart`

- [ ] **Step 1: Update imports and orchestration in setup.dart**

Replace the `service_logger_http_step.dart` import with:

```dart
import 'src/integration/integration_scanner.dart';
import 'src/steps/http_bind_step.dart';
import 'src/steps/logger_bind_step.dart';
import 'src/steps/verify_step.dart';
```

Replace the old "Step 4: Bind Logger & Http services" block:

```dart
  final servicesBound = ServiceLoggerHttpStep(projectRoot).run();
  CliPrinter.divider();
```

with:

```dart
  // ── Step 4: Scan integration targets ──────────────────────────────────────
  final targets = IntegrationScanner(projectRoot).scan();

  // ── Step 5: Bind logger (aborts if missing) ───────────────────────────────
  LoggerBindStep(targets.logger).run();
  CliPrinter.divider();

  // ── Step 6: Bind HTTP layer (graceful skip if missing) ────────────────────
  final servicesBound = HttpBindStep(targets).run();
  CliPrinter.divider();

  // ── Step 7: Verify (format + analyze, report only) ────────────────────────
  final touched = <String>[
    if (targets.logger.found) targets.logger.filePath!,
    if (targets.dio.found) targets.dio.filePath!,
    if (targets.httpWrap.found) targets.httpWrap.filePath!,
  ];
  await VerifyStep(projectRoot, touched).run();
  CliPrinter.divider();
```

- [ ] **Step 2: Delete the obsolete step**

```bash
git rm bin/src/steps/service_logger_http_step.dart
```

- [ ] **Step 3: Verify analysis**

Run: `dart analyze bin/`
Expected: No issues (no remaining references to ServiceLoggerHttpStep).

- [ ] **Step 4: Commit**

```bash
git add bin/setup.dart
git commit -m "refactor(setup): wire scanner + bind/verify steps, drop monolithic service step"
```

---

## Task 10: Idempotency integration test + manual run on FesoRide

**Files:**
- Test: `test/setup/idempotency_test.dart`

- [ ] **Step 1: Write the idempotency test**

```dart
import 'package:test/test.dart';
import '../../bin/src/integration/logger_binder.dart';
import '../../bin/src/integration/http_binder.dart';

void main() {
  test('logger binder: running twice equals running once', () {
    const src = '''
import 'package:logger/logger.dart';
class LoggerService {
  static final Logger _logger = Logger(output: ConsoleOutput());
}
''';
    final once = bindLogger(src)!;
    final twice = bindLogger(once);
    expect(twice, isNull, reason: 'second pass must be a no-op');
  });

  test('dio binder: running twice equals running once', () {
    const src = 'class N { final dio = Dio(); }';
    final once = bindDio(src)!;
    expect(bindDio(once), isNull);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `dart test test/setup/idempotency_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 3: Run full test suite**

Run: `dart test test/setup/`
Expected: All setup tests PASS.

- [ ] **Step 4: Manual smoke test on a copy of FesoRide**

```bash
cp -R /Users/umairhashmi/StudioProjects/FesoRide-APP /tmp/feso_test
# restore from .bak so we start clean (FesoRide already ran old setup)
cd /tmp/feso_test
[ -f lib/app/services/logger_service.dart.bak ] && cp lib/app/services/logger_service.dart.bak lib/app/services/logger_service.dart
[ -f lib/app/services/https_calls.dart.bak ] && cp lib/app/services/https_calls.dart.bak lib/app/services/https_calls.dart
dart run /Users/umairhashmi/StudioProjects/layerxdebugger/bin/setup.dart /tmp/feso_test
# run twice — second run must report "already bound" everywhere
dart run /Users/umairhashmi/StudioProjects/layerxdebugger/bin/setup.dart /tmp/feso_test
```

Expected: First run binds logger + http; second run reports already-bound with no file diffs. Verify with `git -C /tmp/feso_test diff` showing no change between runs.

- [ ] **Step 5: Commit**

```bash
git add test/setup/idempotency_test.dart
git commit -m "test(setup): assert binder idempotency"
```

---

## Self-Review Notes

- **Spec §4 detection** → Tasks 2 (scanner). **§5 marker model** → Task 1. **§6 per-target** → Tasks 3,4,6. **§7 missing-service** → Task 6 (abort/skip). **§8 dio artifact** → Task 5. **§9 verify** → Task 7. **§10 CLI structure** → Tasks 6,7,9 (+ delete). **§11 edge cases** → Tasks 3,4,10. **§12 testing** → Tasks 1–4,10. **§13 acceptance** → Task 10 manual.
- **Deferred from spec §10:** converting `main_dart_step` / `app_widget_step` to marker blocks. Those steps already guard against duplicate injection via content checks and are out of the logger/http critical path; marker-converting them is a low-risk follow-up, not required for A's acceptance criteria. Tracked as a follow-up, not in this plan.
- **Type consistency:** `bindLogger`, `bindDio`, `bindHttpLegacy` return `String?`; `MarkerBlock.renderBlock/has/replaceBlock/upsertImports`; `IntegrationTargets.{logger,dio,httpWrap,anyHttp}`; `LoggerTarget.{found,filePath,className}` — used consistently across tasks.
