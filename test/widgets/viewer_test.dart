import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
    LayerXViewerState.markClosed();
  });

  testWidgets('LayerXDebugOverlay shows the FAB with an error badge',
      (tester) async {
    LayerXLog.e('boom');

    await tester.pumpWidget(
      const MaterialApp(
        home: LayerXDebugOverlay(child: Scaffold(body: Text('app'))),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.bug_report), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('LayerXDebugOverlay hides the viewer in production',
      (tester) async {
    await LayerXDebugger.initialize(
      config: const LayerXDebugConfig(environment: LayerXEnvironment.prod),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LayerXDebugOverlay(child: Scaffold(body: Text('app'))),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.bug_report), findsNothing);
  });

  testWidgets('overlay hides the FAB while the debugger shell is open',
      (tester) async {
    LayerXLog.i('hi');

    await tester.pumpWidget(
      const MaterialApp(
        home: LayerXDebugOverlay(child: Scaffold(body: Text('app'))),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.pest_control_outlined), findsOneWidget);

    LayerXViewerState.markOpened();
    await tester.pump();
    expect(find.byIcon(Icons.pest_control_outlined), findsNothing);

    LayerXViewerState.markClosed();
    await tester.pump();
    expect(find.byIcon(Icons.pest_control_outlined), findsOneWidget);
  });

  testWidgets('debugger shell renders a captured message in the console',
      (tester) async {
    LayerXLog.i('hello viewer');

    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Console'));
    await tester.pumpAndSettle();

    expect(find.textContaining('hello viewer'), findsWidgets);
  });
}
