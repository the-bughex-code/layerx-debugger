// Task D: every count surface (FAB badge, settings tile) reads
// LayerXLogStore.openProblemCount instead of ad-hoc error/total counts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';

void main() {
  setUp(() async {
    await LayerXDebugger.initialize();
    LayerXLogStore.clear();
    LayerXViewerState.markClosed();
  });

  group('FAB badge reads openProblemCount', () {
    testWidgets('2 errors + 3 infos + 1 warning -> badge shows 3',
        (tester) async {
      LayerXLog.e('err 1');
      LayerXLog.e('err 2');
      LayerXLog.i('info 1');
      LayerXLog.i('info 2');
      LayerXLog.i('info 3');
      LayerXLog.w('warn 1');

      expect(LayerXLogStore.openProblemCount, 3);

      await tester.pumpWidget(
        const MaterialApp(
          home: LayerXDebugOverlay(child: Scaffold(body: Text('app'))),
        ),
      );
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('3 infos only -> no badge shown', (tester) async {
      LayerXLog.i('info 1');
      LayerXLog.i('info 2');
      LayerXLog.i('info 3');

      expect(LayerXLogStore.openProblemCount, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: LayerXDebugOverlay(child: Scaffold(body: Text('app'))),
        ),
      );
      await tester.pump();

      // No problems -> badge is hidden entirely (not merely "0").
      expect(find.text('0'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('settings tile subtitle reads openProblemCount', () {
    testWidgets('2 errors + 3 infos + 1 warning -> subtitle "3 problems"',
        (tester) async {
      LayerXLog.e('err 1');
      LayerXLog.e('err 2');
      LayerXLog.i('info 1');
      LayerXLog.i('info 2');
      LayerXLog.i('info 3');
      LayerXLog.w('warn 1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LayerXDebugSettingsButton()),
        ),
      );
      await tester.pump();

      expect(find.text('3 problems'), findsOneWidget);
    });

    testWidgets('3 infos only -> subtitle "0 problems"', (tester) async {
      LayerXLog.i('info 1');
      LayerXLog.i('info 2');
      LayerXLog.i('info 3');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LayerXDebugSettingsButton()),
        ),
      );
      await tester.pump();

      expect(find.text('0 problems'), findsOneWidget);
    });
  });
}
