import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

/// UX P4 Task C — first-run coach mark.
///
/// The very first time the FAB mounts in a session, a small dismissible bubble
/// ("Found a bug? Tap here.") introduces it. It shows exactly once (in-memory
/// flag, session-scoped per the spec), auto-dismisses, and tapping it opens the
/// debugger too.

const _coachText = 'Found a bug? Tap here.';

Future<void> _installFab(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
  final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
  LayerXOverlayInstaller.installInto(overlay);
  await tester.pump(); // deferred post-frame insert
  await tester.pump(const Duration(milliseconds: 600)); // settle the entrance
}

Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  setUp(() {
    LayerXOverlayInstaller.reset(); // also re-arms the coach mark
    LayerXLogStore.clear();
    LayerXViewerState.isOpen.value = false;
  });
  tearDown(() {
    LayerXOverlayInstaller.reset();
    LayerXLogStore.clear();
    LayerXViewerState.isOpen.value = false;
  });

  testWidgets('shows once on first mount, never again in the session',
      (tester) async {
    await _installFab(tester);
    expect(find.text(_coachText), findsOneWidget);

    // Hide the viewer's trigger layer (as opening the shell would) so the FAB
    // is disposed, then bring it back: the coach must NOT reappear.
    LayerXViewerState.isOpen.value = true;
    await tester.pump();
    expect(find.byType(LxFabTrigger), findsNothing);

    LayerXViewerState.isOpen.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LxFabTrigger), findsOneWidget);
    expect(find.text(_coachText), findsNothing);
  });

  testWidgets('auto-dismisses after its timeout', (tester) async {
    await _installFab(tester);
    expect(find.text(_coachText), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text(_coachText), findsNothing);
  });

  testWidgets('the × dismisses the bubble without opening the debugger',
      (tester) async {
    await _installFab(tester);
    expect(find.text(_coachText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text(_coachText), findsNothing);
    expect(find.byType(LxDebuggerShell), findsNothing);
  });

  testWidgets('tapping the bubble dismisses it AND opens the debugger',
      (tester) async {
    await _installFab(tester);
    expect(find.text(_coachText), findsOneWidget);

    await tester.tap(find.text(_coachText));
    await _pumpFrames(tester, const Duration(milliseconds: 500));
    expect(find.text(_coachText), findsNothing);
    expect(find.byType(LxDebuggerShell), findsOneWidget);
  });
}
