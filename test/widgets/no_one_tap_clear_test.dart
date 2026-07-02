import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  testWidgets('the shell app bar has no one-tap clear icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
  });
}
