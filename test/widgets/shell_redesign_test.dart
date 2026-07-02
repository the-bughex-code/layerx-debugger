import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';

/// Verifies the Neo Terminal redesign lays out every surface without a
/// RenderFlex overflow on a small phone screen. Overflow surfaces as a thrown
/// FlutterError, which `tester.takeException()` returns — so a clean run proves
/// the "no overflow" requirement, and walking Problems, Everything (with its
/// Console/Network/Dashboard sub-switch) and a pushed detail proves every
/// surface renders.
void main() {
  setUp(() async {
    // Disable the crash handler so a layout overflow surfaces through
    // `tester.takeException()` instead of being captured by LayerX.
    LayerXDebugger.resetForTesting();
    await LayerXDebugger.initialize(
      config: const LayerXDebugConfig(enableCrashLogs: false),
    );
    LayerXLogStore.clear();
    LayerXViewerState.markClosed();
  });

  testWidgets('every surface lays out without overflow on a 320px screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Seed a mix that exercises long endpoints, errors, warnings and a schema
    // change — the things most likely to overflow a narrow row.
    LayerXNetworkLogger.record(
      endpoint:
          'https://api.test/users/with/a/deliberately/very/long/path/segment/that/could/overflow?expand=profile,settings,roles',
      method: 'GET',
      statusCode: 200,
      responseBody: '{"ok":true}',
      durationMs: 120,
    );
    LayerXNetworkLogger.record(
      endpoint: 'https://api.test/auth/login',
      method: 'POST',
      statusCode: 500,
      responseBody: '{"message":"internal server error, something broke badly"}',
      durationMs: 2200,
    );
    LayerXLog.e('A fairly long error message that should ellipsize cleanly',
        error: Exception('boom'));
    LayerXLog.w('A warning line');

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'overflow on Problems');

    // Walk every surface — pumping mid-cross-fade (120ms) as well — to catch
    // transient transition overflows, not just settled layouts.
    await tester.tap(find.text('Everything'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull,
        reason: 'overflow on Everything → Console');

    for (final sub in ['Network', 'Dashboard']) {
      await tester.tap(find.text(sub));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull,
          reason: 'overflow on Everything → $sub');
    }

    await tester.tap(find.text('Problems'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull, reason: 'overflow back on Problems');

    // Push a detail route from a problem row and lay out the Inspector.
    await tester.tap(find.textContaining('A fairly long error message'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Details'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'overflow on pushed detail');
  });
}
