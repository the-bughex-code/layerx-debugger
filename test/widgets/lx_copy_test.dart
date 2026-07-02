// test/widgets/lx_copy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

void main() {
  setUp(LayerXLogStore.clear);
  tearDown(LayerXLogStore.clear);

  Future<int> pumpHost(WidgetTester tester, void Function(BuildContext) onTap) async {
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    return clipboardCalls; // captured by closure; read after taps via tester
  }

  testWidgets('copy shows exactly one snackbar even on rapid double-tap',
      (tester) async {
    await pumpHost(tester, (c) => LxCopy.copy(c, 'text'));
    await tester.tap(find.text('go'));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Copied — paste it into your bug report'), findsOneWidget);
  });

  testWidgets('copyExport on an empty store copies nothing and says so',
      (tester) async {
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => LxCopy.copyExport(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Nothing captured yet'), findsOneWidget);
    expect(clipboardCalls, 0);
  });
}
