import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/services/logger/layerx_console_capture.dart';

/// Reproduces the ANR condition at scale: a chatty app whose logger
/// pretty-prints a large payload emits hundreds–thousands of console lines while
/// a screen builds. Each captured line goes through `LayerXConsoleCapture.capture`
/// → `LayerXLogOutput.ingest`. Before the fix, ingest captured
/// `StackTrace.current` twice per line — on a debug device that ran into seconds
/// on the UI thread → ANR. After the fix the console path skips the capture
/// entirely, so a flood is bounded and cheap.
void main() {
  setUp(LayerXLogStore.clear);

  test('a 3000-line console flood is captured cheaply, with NO per-line '
      'StackTrace.current (the ANR path is gone)', () {
    const lines = 3000; // ~ a big pretty-printed JSON body dumped by a logger

    final sw = Stopwatch()..start();
    for (var i = 0; i < lines; i++) {
      // capture() is exactly what the debugPrint override calls per line; calling
      // it directly isolates our ingest cost from debugPrint's own console I/O.
      LayerXConsoleCapture.capture('flood line $i field=$i value=${i * 7}');
    }
    sw.stop();

    final logs = LayerXLogStore.logs;
    expect(logs, isNotEmpty);
    // Proof the expensive path is skipped: not one captured line resolved a
    // source location (which is what forced StackTrace.current before).
    expect(
      logs.every((l) => l.sourceFile == null && l.screenName == null),
      isTrue,
      reason: 'console lines must not trigger source resolution',
    );
    // Generous ceiling — cheap ingests clear this by a wide margin. A regression
    // that re-introduces per-line stack capture would blow past it.
    expect(sw.elapsedMilliseconds, lessThan(2000),
        reason: '$lines console lines took ${sw.elapsedMilliseconds}ms');

    // ignore: avoid_print
    print('VERIFY: $lines console lines in ${sw.elapsedMilliseconds}ms '
        '(${(sw.elapsedMicroseconds / lines).toStringAsFixed(1)} us/line)');
  });
}
