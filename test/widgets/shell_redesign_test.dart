import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';

/// Verifies the redesign lays out every surface without a RenderFlex overflow.
/// Overflow surfaces as a thrown FlutterError, which `tester.takeException()`
/// returns — so a clean run proves the "no overflow" requirement, and walking
/// Problems, Everything (with its Console/Network/Dashboard sub-switch) and a
/// pushed detail proves every surface renders.
///
/// UX P4 hardens this against **1.5× dynamic type** and **RTL** locales: the
/// same walk runs under `MediaQuery(textScaler: 1.5)` and under
/// `Directionality.rtl`, so growing text or a mirrored layout can't silently
/// clip a row, chip, or the detail bottom bar.

/// Seeds a mix that exercises long endpoints, errors, warnings and a schema
/// change — the things most likely to overflow a narrow row.
void _seed() {
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
}

/// Wraps the shell in a `MaterialApp` whose `builder` (so it applies to pushed
/// routes too) optionally forces a text scale and/or RTL direction.
Widget _app({double textScale = 1.0, bool rtl = false}) {
  return MaterialApp(
    home: const LxDebuggerShell(),
    builder: (context, child) {
      Widget wrapped = child!;
      if (textScale != 1.0) {
        wrapped = MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: wrapped,
        );
      }
      if (rtl) {
        wrapped =
            Directionality(textDirection: TextDirection.rtl, child: wrapped);
      }
      return wrapped;
    },
  );
}

/// Walks Problems → Everything (Console/Network/Dashboard) → back → pushed
/// detail, asserting no overflow at each step (pumping mid-cross-fade too, to
/// catch transient transition overflows, not just settled layouts).
Future<void> _walk(WidgetTester tester, String tag) async {
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull, reason: '$tag: overflow on Problems');

  await tester.tap(find.text('Everything'));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 450));
  expect(tester.takeException(), isNull,
      reason: '$tag: overflow on Everything → Console');

  for (final sub in ['Network', 'Dashboard']) {
    await tester.tap(find.text(sub));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull,
        reason: '$tag: overflow on Everything → $sub');
  }

  await tester.tap(find.text('Problems'));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 450));
  expect(tester.takeException(), isNull,
      reason: '$tag: overflow back on Problems');

  await tester.tap(find.textContaining('A fairly long error message'));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 450));
  expect(find.text('Details'), findsOneWidget);
  expect(tester.takeException(), isNull,
      reason: '$tag: overflow on pushed detail');
}

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

    _seed();
    await tester.pumpWidget(_app());
    await _walk(tester, '320px');
  });

  testWidgets('no overflow under 1.5× dynamic type', (tester) async {
    // A roomier canvas than 320px: 1.5× text on the narrowest phone is an
    // unrealistic double-worst-case; a normal phone at 1.5× is the real target.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    _seed();
    await tester.pumpWidget(_app(textScale: 1.5));
    await _walk(tester, '1.5x');
  });

  testWidgets('no overflow under RTL', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    _seed();
    await tester.pumpWidget(_app(rtl: true));
    await _walk(tester, 'rtl');
  });
}
