import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

void main() {
  setUp(() {
    LayerXOverlayInstaller.reset();
    LayerXViewerState.isOpen.value = false;
  });
  tearDown(() {
    LayerXOverlayInstaller.reset();
    LayerXViewerState.isOpen.value = false;
  });

  testWidgets('installInto renders the FAB into the app overlay, reset removes it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);

    LayerXOverlayInstaller.installInto(overlay);
    await tester.pump(); // deferred post-frame insert
    await tester.pump(const Duration(milliseconds: 600)); // let it settle

    expect(find.byType(LxFabTrigger), findsOneWidget);

    LayerXOverlayInstaller.reset();
    await tester.pump();
    expect(find.byType(LxFabTrigger), findsNothing);
  });

  testWidgets('installInto is idempotent — never more than one FAB',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);

    LayerXOverlayInstaller.installInto(overlay);
    LayerXOverlayInstaller.installInto(overlay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LxFabTrigger), findsOneWidget);
  });

  testWidgets(
      'FAB auto-installs via the route observer with NO builder wiring',
      (tester) async {
    // This is the real-world scenario: an app that only added the route
    // observer to navigatorObservers and never wrapped LayerXDebugOverlay.
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [LayerXDebugger.routeObserver],
        home: const Scaffold(body: Text('app')),
      ),
    );
    await tester.pump(); // deferred insert from didPush
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LxFabTrigger), findsOneWidget);
  });

  testWidgets('triggers hide while the viewer shell is open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);

    LayerXOverlayInstaller.installInto(overlay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LxFabTrigger), findsOneWidget);

    LayerXViewerState.isOpen.value = true;
    await tester.pump();
    expect(find.byType(LxFabTrigger), findsNothing);
  });
}
