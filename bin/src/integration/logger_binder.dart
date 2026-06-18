import '../util/marker_block.dart';

const _debuggerImport =
    "import 'package:layerx_debugger/layerx_debugger.dart';";
final _loggerCtorRe =
    RegExp(r'static\s+final\s+Logger\s+\w+\s*=\s*Logger\(');

/// Binds [LayerXLogInterceptorOutput] into a `logger`-package Logger.
///
/// Returns the patched source, or null if the file is not a logger file or is
/// already bound (idempotent: a second pass over its own output returns null).
String? bindLogger(String source) {
  if (!_loggerCtorRe.hasMatch(source)) return null;
  if (source.contains('LayerXLogInterceptorOutput')) return null;

  var out = source;

  if (out.contains('LxLogOutput()')) {
    // 1. Legacy in-project output -> canonical package output.
    out = out.replaceAll('LxLogOutput()', 'LayerXLogInterceptorOutput()');
  } else if (RegExp(r'output:\s*ConsoleOutput\(\)').hasMatch(out)) {
    // 2. output: ConsoleOutput() -> MultiOutput([...]).
    out = out.replaceFirst(
      RegExp(r'output:\s*ConsoleOutput\(\)'),
      'output: MultiOutput([ConsoleOutput(), LayerXLogInterceptorOutput()])',
    );
  } else if (RegExp(r'MultiOutput\(\s*\[').hasMatch(out) &&
      out.contains('ConsoleOutput()')) {
    // 3. Existing MultiOutput without our output -> append.
    out = out.replaceFirst(
      'ConsoleOutput()',
      'ConsoleOutput(), LayerXLogInterceptorOutput()',
    );
  } else {
    // 4. No output: param — insert a marker-wrapped one before the ctor's ).
    final m = _loggerCtorRe.firstMatch(out)!;
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

  // Ensure the package import exists (its own marker block).
  if (!out.contains(_debuggerImport)) {
    out = MarkerBlock.upsertImports(out, [_debuggerImport]);
  }
  // Safety: collapse any accidental double commas.
  out = out.replaceAll(RegExp(r',(\s*),'), r',$1');
  return out;
}
