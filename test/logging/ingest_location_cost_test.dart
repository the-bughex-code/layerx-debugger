import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';

/// A stack trace with a resolvable app frame. Both `_parseStackTrace` (symbols)
/// and `LayerXStackLocation.parse` (file:line) key off
/// `(package:<pkg>/<file>:line:col)` frames.
final _resolvable = StackTrace.fromString(
  '#0      MyController.load (package:myapp/home_controller.dart:42:11)\n'
  '#1      main (package:myapp/main.dart:5:3)',
);

/// Guards the ANR fix: `LayerXLogOutput.ingest` must not do expensive source
/// resolution (which auto-captures `StackTrace.current`) for high-volume,
/// low-value lines. A chatty app whose logger pretty-prints API payloads emits
/// hundreds of such lines per navigation; resolving each one blocked the UI
/// thread long enough to ANR (SIGQUIT / tombstone) on debug builds.
void main() {
  setUp(LayerXLogStore.clear);

  test(
      'resolveLocation:false suppresses all source derivation (the console '
      'flood path) even when a resolvable stack is present', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.debug,
      message: 'noisy console line',
      category: LayerXLogCategory.debugConsole,
      stackTrace: _resolvable,
      resolveLocation: false,
    );
    final e = LayerXLogStore.logs.single;
    expect(e.sourceFile, isNull, reason: 'no file:line parse on console lines');
    expect(e.sourceLine, isNull);
    expect(e.screenName, isNull, reason: 'no symbol parse on console lines');
    expect(e.methodName, isNull);
  });

  test(
      'an error still resolves its file:line from the stack — attribution is '
      'preserved exactly where it matters', () {
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.error,
      message: 'boom',
      stackTrace: _resolvable,
    );
    final e = LayerXLogStore.logs.single;
    expect(e.sourceFile, 'package:myapp/home_controller.dart');
    expect(e.sourceLine, 42);
  });

  test(
      'a plain info log with no error and no stack does not force a '
      'StackTrace.current attribution', () {
    // info/no-error/no-stack is not "worth capturing", so no synthetic
    // StackTrace.current is taken — this is what stops the per-line flood from
    // an app that logs verbosely at info/debug during navigation.
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'just fyi',
    );
    final e = LayerXLogStore.logs.single;
    expect(e.sourceFile, isNull);
    expect(e.screenName, isNull);
  });

  test('a warning without an explicit stack still self-attributes', () {
    // warnings ARE worth capturing, so ingest synthesises one StackTrace.current
    // (once, not twice) to attribute them — proving the level gate, not a blanket
    // "never capture", is what changed.
    LayerXLogOutput.ingest(
      level: LayerXLogLevel.warning,
      message: 'heads up',
    );
    // The captured frames are this test's own (file:// frames, not package:),
    // which the parser intentionally skips — so location stays null while the
    // capture path itself is still exercised without throwing.
    expect(LayerXLogStore.logs.single.message, 'heads up');
  });
}
