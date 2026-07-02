import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_dashboard_pane.dart';

LayerXLogEntry _net(String id, int ms) => LayerXLogEntry(
      id: id, dedupKey: id, timestamp: DateTime(2026),
      level: LayerXLogLevel.success, source: LayerXLogSource.network,
      message: 'GET ok', endpoint: 'https://x/$id', statusCode: 200,
      journey: const [], extras: {'duration_ms': ms},
    );

void main() {
  testWidgets('AVG LATENCY shows the number with data present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LxDashboardPane(logs: [_net('a', 100), _net('b', 300)], onInspect: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('200ms'), findsOneWidget); // (100+300)/2
    expect(find.text('ms'), findsNothing); // never the bare literal
  });
}
