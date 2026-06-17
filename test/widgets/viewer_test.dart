import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/mvvm/view/lx_log_list_screen.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
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

  testWidgets('log list renders a captured message', (tester) async {
    LayerXLog.i('hello viewer');

    await tester.pumpWidget(const MaterialApp(home: LxLogListScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('hello viewer'), findsWidgets);
  });
}
