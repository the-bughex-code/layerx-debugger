import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';

LayerXLogEntry _entry({
  required String message,
  LayerXLogLevel level = LayerXLogLevel.info,
  LayerXLogSource source = LayerXLogSource.app,
  LayerXLogCategory category = LayerXLogCategory.app,
  String? endpoint,
  int? statusCode,
  String? requestPayload,
  String? responsePayload,
  String? stackTrace,
}) =>
    LayerXLogEntry(
      id: message, dedupKey: message,
      // Recent enough that the DETAILS row reads "5m ago", not a date.
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      level: level, source: source, category: category, message: message,
      endpoint: endpoint, statusCode: statusCode,
      requestPayload: requestPayload, responsePayload: responsePayload,
      stackTrace: stackTrace, journey: const [], extras: const {},
    );

Future<void> _pump(WidgetTester tester, LayerXLogEntry e) async {
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: LxInspectorPane(log: e))));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'a 500 entry leads with WHO TO ASSIGN & WHY and puts request above response',
      (tester) async {
    // Tall surface so the whole single-scroll report lays out at once and the
    // request/response positions can be compared directly.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final e = _entry(
      message: 'API Error',
      level: LayerXLogLevel.error,
      source: LayerXLogSource.server,
      category: LayerXLogCategory.api,
      endpoint: 'https://api.test/users',
      statusCode: 500,
      requestPayload: '{"req":"ping"}',
      responsePayload: '{"resp":"pong"}',
    );
    await _pump(tester, e);

    // The old 4-tab strip is gone entirely.
    for (final tab in ['Overview', 'Response', 'Request', 'Trace']) {
      expect(find.text(tab), findsNothing,
          reason: "old '$tab' tab should not render");
    }

    // Blame leads the report with the 5xx verdict.
    expect(find.text('WHO TO ASSIGN & WHY'), findsOneWidget);
    expect(find.textContaining('Backend'), findsWidgets);

    // Request sits ABOVE response — both as section labels and payload bodies.
    final requestLabelDy =
        tester.getTopLeft(find.text('WHAT THE APP SENT (REQUEST)')).dy;
    final responseLabelDy =
        tester.getTopLeft(find.text('WHAT THE SERVER ANSWERED (RESPONSE)')).dy;
    expect(requestLabelDy, lessThan(responseLabelDy));

    final requestBodyDy = tester.getTopLeft(find.textContaining('"req"')).dy;
    final responseBodyDy = tester.getTopLeft(find.textContaining('"resp"')).dy;
    expect(requestBodyDy, lessThan(responseBodyDy));
  });

  testWidgets('DETAILS shows the friendly source label and relative time',
      (tester) async {
    final e = _entry(
      message: 'API Error',
      level: LayerXLogLevel.error,
      source: LayerXLogSource.server,
      category: LayerXLogCategory.api,
      endpoint: 'https://api.test/users',
      statusCode: 500,
    );
    await _pump(tester, e);

    // The report ListView is the first Scrollable (SelectableText embeds its
    // own scrollable, so byType alone can be ambiguous).
    await tester.scrollUntilVisible(find.text('🖥 Server Error'), 80,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('🖥 Server Error'), findsOneWidget);
    // No bare enum-name row…
    expect(find.text('server'), findsNothing);
    // …and the time row is relative, not an ISO-8601 dump.
    expect(find.textContaining('ago'), findsOneWidget);
    expect(find.textContaining('${DateTime.now().year}-'), findsNothing);
  });

  testWidgets('an info entry shows neither blame nor technical details',
      (tester) async {
    final e = _entry(message: 'just info');
    await _pump(tester, e);

    expect(find.textContaining('WHO TO ASSIGN'), findsNothing);
    expect(find.text('TECHNICAL DETAILS'), findsNothing);
    // Empty payload sections are omitted entirely — no empty-state screens.
    expect(find.textContaining('(REQUEST)'), findsNothing);
    expect(find.textContaining('(RESPONSE)'), findsNothing);
    expect(find.textContaining('NO RESPONSE'), findsNothing);
  });
}
