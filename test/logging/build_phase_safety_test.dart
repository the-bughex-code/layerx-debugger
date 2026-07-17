import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

/// Regression tests for the mid-navigation freeze/crash:
///
/// The store used to fire `logsNotifier` synchronously. A log emitted during
/// the BUILD phase (a GetX controller's `onInit` while its route builds,
/// `LayerXLog.screen()` called from `build()`, a nested Navigator's initial
/// `didPush` inside `initState`, or any FlutterError reported during build)
/// ran `setState` on the always-mounted FAB listener mid-build →
/// "setState() or markNeedsBuild() called during build". With the crash
/// handler installed, that reported error was re-ingested into the same
/// notifier, re-throwing per notification — unbounded recursion that froze
/// the app. The store must therefore never notify while a frame is building.
LayerXLogEntry _entry(String id, {String message = 'm', String? dedupKey}) {
  return LayerXLogEntry(
    id: id,
    dedupKey: dedupKey ?? id,
    timestamp: DateTime.now(),
    level: LayerXLogLevel.info,
    source: LayerXLogSource.app,
    message: message,
    journey: const [],
    extras: const {},
  );
}

void main() {
  setUp(() {
    LayerXLogStore.clear();
    LayerXLogStore.maxStoredLogs = 500;
  });

  testWidgets('add() during build never notifies listeners synchronously',
      (tester) async {
    var emitInBuild = false;
    late StateSetter rebuildLogger;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            // Mimics the FAB pill: an always-mounted listener on the store.
            ValueListenableBuilder<List<LayerXLogEntry>>(
              valueListenable: LayerXLogStore.logsNotifier,
              builder: (_, logs, __) => Text('count:${logs.length}'),
            ),
            // Mimics a screen whose construction logs (onInit / build logging).
            StatefulBuilder(
              builder: (context, setState) {
                rebuildLogger = setState;
                if (emitInBuild) {
                  LayerXLogStore.add(_entry('build-log'));
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    emitInBuild = true;
    rebuildLogger(() {});
    await tester.pump();

    // Before the fix this surfaced "setState() or markNeedsBuild() called
    // during build" from the listener.
    expect(tester.takeException(), isNull);

    // The store's synchronous truth already contains the entry…
    expect(LayerXLogStore.logs, hasLength(1));

    // …and listeners catch up on the next frame.
    emitInBuild = false;
    await tester.pump();
    expect(find.text('count:1'), findsOneWidget);
  });

  testWidgets('updateLog() during build (duplicate path) is also deferred',
      (tester) async {
    LayerXLogStore.add(_entry('dup', dedupKey: 'same'));

    var emitInBuild = false;
    late StateSetter rebuildLogger;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ValueListenableBuilder<List<LayerXLogEntry>>(
              valueListenable: LayerXLogStore.logsNotifier,
              builder: (_, logs, __) =>
                  Text('occ:${logs.isEmpty ? 0 : logs.first.occurrenceCount}'),
            ),
            StatefulBuilder(
              builder: (context, setState) {
                rebuildLogger = setState;
                if (emitInBuild) {
                  final dup = LayerXLogStore.logs.first;
                  dup.occurrenceCount++;
                  LayerXLogStore.updateLog(dup);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    emitInBuild = true;
    rebuildLogger(() {});
    await tester.pump();

    expect(tester.takeException(), isNull);

    emitInBuild = false;
    await tester.pump();
    expect(find.text('occ:2'), findsOneWidget);
  });

  testWidgets('a burst of adds coalesces into one notification per frame',
      (tester) async {
    var rebuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<List<LayerXLogEntry>>(
          valueListenable: LayerXLogStore.logsNotifier,
          builder: (_, logs, __) {
            rebuilds++;
            return Text('count:${logs.length}');
          },
        ),
      ),
    );
    final baseline = rebuilds;

    // A synchronous flood — e.g. console capture during navigation.
    for (var i = 0; i < 100; i++) {
      LayerXLogStore.add(_entry('flood-$i'));
    }
    expect(LayerXLogStore.logs, hasLength(100));

    await tester.pump();
    await tester.pump();
    expect(find.text('count:100'), findsOneWidget);

    // The listener must not have been rebuilt once per add.
    expect(rebuilds - baseline, lessThanOrEqualTo(2));
  });

  testWidgets(
      'a FlutterError reported during build cannot cascade through the store',
      (tester) async {
    final previousOnError = FlutterError.onError;
    LayerXCrashHandler.install();
    addTearDown(() {
      LayerXCrashHandler.uninstall();
      FlutterError.onError = previousOnError;
    });

    var reportInBuild = false;
    late StateSetter rebuildReporter;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ValueListenableBuilder<List<LayerXLogEntry>>(
              valueListenable: LayerXLogStore.logsNotifier,
              builder: (_, logs, __) => Text('count:${logs.length}'),
            ),
            StatefulBuilder(
              builder: (context, setState) {
                rebuildReporter = setState;
                if (reportInBuild) {
                  // e.g. a RenderFlex overflow / build error on the new route.
                  FlutterError.reportError(
                    FlutterErrorDetails(
                      exception: StateError('boom during build'),
                      stack: StackTrace.current,
                      library: 'test',
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    reportInBuild = true;
    rebuildReporter(() {});
    await tester.pump();

    // The app's own error is expected to surface once — but exactly once:
    // before the fix this recursed until the console flooded and the stack
    // overflowed.
    final reported = tester.takeException();
    expect(reported, isA<StateError>());

    reportInBuild = false;
    await tester.pump();

    final crashEntries = LayerXLogStore.logs
        .where((l) => l.message.contains('boom during build'))
        .toList();
    expect(crashEntries, hasLength(1));
    expect(crashEntries.first.occurrenceCount, 1);
  });
}
