// Task E: user-facing jargon (Δ, SCHEMA, CONTRACT) swept for plain language.
// API identifiers like `schemaChanges` are unaffected — only display strings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_schema_change.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_network_pane.dart';

LayerXLogEntry _networkEntry({
  required String id,
  bool responseChanged = false,
}) =>
    LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: LayerXLogLevel.success,
      source: LayerXLogSource.network,
      category: LayerXLogCategory.app,
      message: id,
      endpoint: 'https://api.test/$id',
      methodName: 'GET',
      statusCode: 200,
      journey: const [],
      extras: const {},
      responseChanged: responseChanged,
    );

LayerXLogEntry _entryWithSchemaChanges() => LayerXLogEntry(
      id: 'contract-shifted',
      dedupKey: 'contract-shifted',
      timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      level: LayerXLogLevel.success,
      source: LayerXLogSource.network,
      category: LayerXLogCategory.app,
      message: 'GET /users changed shape',
      endpoint: 'https://api.test/users',
      methodName: 'GET',
      statusCode: 200,
      journey: const [],
      extras: const {},
      responseChanged: true,
      schemaChanges: const [
        LayerXSchemaChange(
          key: 'data.user.role',
          diffType: LayerXSchemaDiffType.valueChanged,
          previousValue: 'member',
          currentValue: 'admin',
        ),
      ],
    );

void main() {
  group('network pane wording', () {
    testWidgets('the filter chip reads CHANGED, not Δ CHANGED',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxNetworkPane(
              logs: [_networkEntry(id: 'a', responseChanged: true)],
              onInspect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Δ Changed'), findsNothing);
      expect(find.textContaining('Δ'), findsNothing);
      expect(find.text('Changed'), findsOneWidget);
    });

    testWidgets('a changed-response row status text has no Δ marker',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxNetworkPane(
              logs: [_networkEntry(id: 'b', responseChanged: true)],
              onInspect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('200Δ'), findsNothing);
      expect(find.text('200'), findsOneWidget);
    });
  });

  group('inspector pane wording', () {
    testWidgets(
        'a schema-changed entry shows RESPONSE CHANGED SHAPE, not CONTRACT '
        'CHANGES', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LxInspectorPane(log: _entryWithSchemaChanges()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESPONSE CHANGED SHAPE'), findsOneWidget);
      expect(find.text('CONTRACT CHANGES'), findsNothing);
    });
  });
}
