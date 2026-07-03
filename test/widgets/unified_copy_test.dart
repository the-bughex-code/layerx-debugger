import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';

void main() {
  testWidgets('the Inspector payload Copy is no longer silent', (tester) async {
    // Clipboard.setData hits a real platform channel; without a mock handler
    // the call never completes and LxCopy.copy's snackbar never shows.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final e = LayerXLogEntry(
      id: 'x', dedupKey: 'x', timestamp: DateTime(2026),
      level: LayerXLogLevel.error, source: LayerXLogSource.server,
      category: LayerXLogCategory.api, message: 'API Error',
      endpoint: 'https://x/y', statusCode: 500,
      responsePayload: '{"error":true}', journey: const [], extras: const {},
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LxInspectorPane(log: e))));
    await tester.pump(const Duration(milliseconds: 300));
    // The Response tab is gone — the payload copy control now sits inline in
    // the single-scroll report, so scroll down to it before tapping. The
    // report ListView is the first Scrollable (SelectableText embeds its own).
    await tester.scrollUntilVisible(find.text('Copy'), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text(LxCopy.confirmation), findsOneWidget);
  });
}
