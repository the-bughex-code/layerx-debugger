import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';

void main() {
  testWidgets('row copy button copies a summary and does not inspect',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    var inspected = false;
    final e = LayerXLogEntry(
      id: 'x', dedupKey: 'x', timestamp: DateTime(2026, 1, 1, 9, 8, 7),
      level: LayerXLogLevel.error, source: LayerXLogSource.app,
      category: LayerXLogCategory.uiException, message: 'copy me',
      sourceFile: 'lib/a.dart', sourceLine: 12, journey: const [], extras: const {},
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LxConsolePane(logs: [e], onInspect: (_) => inspected = true))));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(inspected, isFalse);
    expect(calls, hasLength(1));
    expect(calls.first.arguments['text'], contains('copy me'));
    expect(calls.first.arguments['text'], contains('lib/a.dart:12'));
  });
}
