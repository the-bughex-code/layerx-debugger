import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_dashboard_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_network_pane.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

const _pausedBannerText = 'Paused — new activity is hidden until you resume';

LayerXLogEntry _entry(
  String id, {
  LayerXLogLevel level = LayerXLogLevel.info,
  LayerXLogCategory category = LayerXLogCategory.app,
  String? endpoint,
  String? method,
  int? statusCode,
}) =>
    LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: DateTime(2026, 1, 1, 10),
      level: level,
      source: LayerXLogSource.app,
      category: category,
      message: id,
      methodName: method,
      endpoint: endpoint,
      statusCode: statusCode,
      journey: const [],
      extras: const {},
    );

/// Delivers [total] as a run of small discrete frames rather than one jump —
/// a single large pump can leave a route transition mid-composite, so
/// stepping through smaller frames lets each transition actually reach and
/// paint its terminal frame.
Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

Widget _host(Widget pane) => MaterialApp(home: Scaffold(body: pane));

void main() {
  group('console honest states', () {
    testWidgets(
        'search matching nothing shows NOTHING MATCHES and Clear filters '
        'restores the rows', (tester) async {
      final logs = [
        _entry('alpha row'),
        _entry('beta row'),
        _entry('gamma row'),
      ];
      await tester
          .pumpWidget(_host(LxConsolePane(logs: logs, onInspect: (_) {})));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('NOTHING MATCHES'), findsOneWidget);
      expect(find.textContaining('Showing 0 of 3'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('alpha row'), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('NOTHING MATCHES'), findsNothing);
      expect(find.text('alpha row'), findsOneWidget);
      expect(find.text('beta row'), findsOneWidget);
      expect(find.text('gamma row'), findsOneWidget);
      // The search field itself was cleared, not just the state behind it.
      expect(find.text('zzz'), findsNothing);
    });

    testWidgets(
        'category filter hiding 1 of 3 shows the summary bar and Show all '
        'restores', (tester) async {
      final logs = [
        _entry('first app row'),
        _entry('second app row'),
        _entry('a ui overflow row', category: LayerXLogCategory.uiException),
      ];
      await tester
          .pumpWidget(_host(LxConsolePane(logs: logs, onInspect: (_) {})));
      await tester.pumpAndSettle();
      expect(find.text('Showing 2 of 3'), findsNothing);

      await tester.tap(find.text('App Logs'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 2 of 3'), findsOneWidget);
      expect(find.text('Show all'), findsOneWidget);
      expect(find.text('a ui overflow row'), findsNothing);
      expect(find.text('first app row'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 2 of 3'), findsNothing);
      expect(find.text('a ui overflow row'), findsOneWidget);
      expect(find.text('first app row'), findsOneWidget);
      expect(find.text('second app row'), findsOneWidget);
    });

    testWidgets('truly-empty console keeps NO LOGS and offers no recovery',
        (tester) async {
      await tester.pumpWidget(
          _host(LxConsolePane(logs: const [], onInspect: (_) {})));
      await tester.pumpAndSettle();

      expect(find.text('NO LOGS'), findsOneWidget);
      expect(find.text('NOTHING MATCHES'), findsNothing);
      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Show all'), findsNothing);
    });
  });

  group('network honest states', () {
    final requests = [
      _entry('users ok',
          endpoint: 'https://api.test/users', method: 'GET', statusCode: 200),
      _entry('login boom',
          endpoint: 'https://api.test/auth/login',
          method: 'POST',
          statusCode: 500),
    ];

    testWidgets(
        'query matching nothing shows NOTHING MATCHES and Clear filters '
        'restores the rows', (tester) async {
      await tester
          .pumpWidget(_host(LxNetworkPane(logs: requests, onInspect: (_) {})));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('NOTHING MATCHES'), findsOneWidget);
      expect(find.textContaining('Showing 0 of 2'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('NOTHING MATCHES'), findsNothing);
      expect(find.text('/users'), findsOneWidget);
      expect(find.text('/auth/login'), findsOneWidget);
      expect(find.text('zzz'), findsNothing);
    });

    testWidgets('chip filter hiding 1 of 2 shows the summary bar and Show all',
        (tester) async {
      await tester
          .pumpWidget(_host(LxNetworkPane(logs: requests, onInspect: (_) {})));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1 of 2'), findsOneWidget);
      expect(find.text('/users'), findsNothing);
      expect(find.text('/auth/login'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1 of 2'), findsNothing);
      expect(find.text('/users'), findsOneWidget);
    });

    testWidgets('truly-empty network keeps NO REQUESTS and offers no recovery',
        (tester) async {
      await tester.pumpWidget(_host(
          LxNetworkPane(logs: [_entry('not network')], onInspect: (_) {})));
      await tester.pumpAndSettle();

      expect(find.text('NO REQUESTS'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });
  });

  group('paused banner', () {
    setUp(LayerXLogStore.clear);
    tearDown(LayerXLogStore.clear);

    testWidgets(
        'pausing via the overflow menu shows the banner on both segments and '
        'the banner Resume restores live flow', (tester) async {
      LayerXLogStore.add(_entry('first problem', level: LayerXLogLevel.error));

      await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_pausedBannerText), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await _pumpFrames(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Pause live updates'));
      await _pumpFrames(tester, const Duration(milliseconds: 400));

      // Banner on Problems…
      expect(find.text(_pausedBannerText), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      // …and on Everything.
      await tester.tap(find.text('Everything'));
      await _pumpFrames(tester, const Duration(milliseconds: 400));
      expect(find.text(_pausedBannerText), findsOneWidget);

      // While paused, new logs do not flow into the console.
      LayerXLogStore.add(_entry('arrived while paused'));
      await tester.pump();
      expect(find.text('arrived while paused'), findsNothing);

      // Resume straight from the banner.
      await tester.tap(find.text('Resume'));
      await _pumpFrames(tester, const Duration(milliseconds: 400));

      expect(find.text(_pausedBannerText), findsNothing);
      expect(find.text('arrived while paused'), findsOneWidget);
    });
  });

  group('dashboard score label', () {
    testWidgets('health hero carries the developer-metric caption',
        (tester) async {
      await tester.pumpWidget(_host(
          LxDashboardPane(logs: [_entry('an app log')], onInspect: (_) {})));
      await tester.pumpAndSettle();

      expect(
        find.text('Developer metric — problems above are what matter'),
        findsOneWidget,
      );
    });
  });
}
