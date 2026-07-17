import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/widgets/lx_edge_trigger.dart';

/// Regression tests for stacked debugger shells during navigation:
///
/// Every open path (FAB tap, edge swipe, `openViewer`, the settings tile) used
/// to push `LxDebuggerShell` unguarded. A rapid double-tap pushed two shells,
/// and — worse — the edge swipe fired once per drag update past the 8px
/// threshold, so a single fast swipe stacked several shells. The user then had
/// to pop each one; "back" appeared broken mid-navigation. All paths now claim
/// a single-flight open via [LayerXViewerState.beginOpen].
void main() {
  setUp(() {
    LayerXViewerState.reset();
    LayerXLogStore.clear();
  });

  testWidgets('openViewer called twice in one frame pushes exactly one shell',
      (tester) async {
    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            appContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    // Two racing opens — e.g. a double-tap, or a tap plus an API callback.
    LayerXDebugger.openViewer(appContext);
    LayerXDebugger.openViewer(appContext);
    await tester.pumpAndSettle();

    expect(find.byType(LxDebuggerShell), findsOneWidget);
  });

  testWidgets('the viewer can be reopened after it is closed', (tester) async {
    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            appContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    LayerXDebugger.openViewer(appContext);
    await tester.pumpAndSettle();
    expect(find.byType(LxDebuggerShell), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(LxDebuggerShell), findsNothing);

    LayerXDebugger.openViewer(appContext);
    await tester.pumpAndSettle();
    expect(find.byType(LxDebuggerShell), findsOneWidget);
  });

  testWidgets('one edge swipe with many drag updates opens exactly one shell',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Stack(children: [LxEdgeTrigger()])),
      ),
    );

    // A fast right-edge swipe: many pointer moves, each past the -8px
    // threshold. Before the latch this pushed one shell per update.
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final gesture =
        await tester.startGesture(Offset(size.width - 5, size.height / 2));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(LxDebuggerShell), findsOneWidget);
  });

  testWidgets('double-tapping the settings tile pushes exactly one shell',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LayerXDebugSettingsButton()),
      ),
    );

    await tester.tap(find.byType(LayerXDebugSettingsButton));
    await tester.tap(find.byType(LayerXDebugSettingsButton),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(LxDebuggerShell), findsOneWidget);
  });

  testWidgets('a failed open releases the claim so a later open still works',
      (tester) async {
    // beginOpen + cancelOpen round-trip: a push that dies must not brick the
    // viewer for the rest of the session.
    expect(LayerXViewerState.beginOpen(), isTrue);
    expect(LayerXViewerState.beginOpen(), isFalse);
    LayerXViewerState.cancelOpen();
    expect(LayerXViewerState.beginOpen(), isTrue);
    LayerXViewerState.cancelOpen();
  });
}
