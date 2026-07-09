import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';

/// UX P4 Task B — reduce-motion + one-shot new-problem pulse.
///
/// The FAB no longer pulses perpetually: the ring runs a few cycles ONLY when a
/// new problem arrives, then rests. Under OS reduce-motion it never runs, and
/// `LxKit.stagger` skips its entrance tween.

LayerXLogEntry _error(String id) => LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: DateTime(2026, 1, 1, 10),
      level: LayerXLogLevel.error,
      source: LayerXLogSource.app,
      category: LayerXLogCategory.app,
      message: id,
      journey: const [],
      extras: const {},
    );

/// Hosts the FAB under an explicit [MediaQuery] whose `disableAnimations` we
/// control — a bare `MaterialApp` would re-derive it from the platform view.
Widget _host({required bool reduceMotion}) => MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: reduceMotion,
      ),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [LxFabTrigger()]),
      ),
    );

const _pulse = ValueKey('lx-fab-pulse');

void main() {
  setUp(() {
    LayerXLogStore.clear();
    LayerXViewerState.isOpen.value = false;
  });
  tearDown(() {
    LayerXLogStore.clear();
    LayerXViewerState.isOpen.value = false;
  });

  group('FAB pulse ring', () {
    testWidgets('rests at start — no ring until a new problem arrives',
        (tester) async {
      await tester.pumpWidget(_host(reduceMotion: false));
      await tester.pump();
      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('a new problem pulses the ring, then it stops on its own',
        (tester) async {
      await tester.pumpWidget(_host(reduceMotion: false));
      await tester.pump();
      expect(find.byKey(_pulse), findsNothing); // at rest

      // A new open problem arrives while the viewer is closed.
      LayerXLogStore.add(_error('boom'));
      await tester.pump(); // builder sees the count grow, schedules the pulse
      await tester.pump(); // post-frame callback starts it
      expect(find.byKey(_pulse), findsOneWidget);

      // It is a one-shot: pumpAndSettle only returns because it terminates
      // (a perpetual ..repeat() would hang here forever).
      await tester.pumpAndSettle();
      expect(find.byKey(_pulse), findsNothing);
    });

    testWidgets('reduce-motion: a new problem never pulses the ring',
        (tester) async {
      await tester.pumpWidget(_host(reduceMotion: true));
      await tester.pump();

      LayerXLogStore.add(_error('boom'));
      await tester.pump();
      await tester.pump();
      // The badge count still changed (that is the signal); the ring never runs.
      expect(find.byKey(_pulse), findsNothing);

      // And there is nothing left animating — pumpAndSettle returns immediately.
      await tester.pumpAndSettle();
      expect(find.byKey(_pulse), findsNothing);
    });
  });

  group('LxKit.stagger', () {
    Widget staggerHost({required bool reduceMotion}) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LxKit.stagger(0, const Text('row')),
          ),
        );

    testWidgets('animates the entrance when reduce-motion is off',
        (tester) async {
      await tester.pumpWidget(staggerHost(reduceMotion: false));
      // The keyed tween wrapper is present and the row starts faded in.
      expect(find.byKey(const ValueKey('lx_stagger_0')), findsOneWidget);
      expect(find.text('row'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('reduce-motion: renders the row directly, no entrance tween',
        (tester) async {
      await tester.pumpWidget(staggerHost(reduceMotion: true));
      // No tween wrapper at all; the row is on screen at full opacity now.
      expect(find.byKey(const ValueKey('lx_stagger_0')), findsNothing);
      expect(find.text('row'), findsOneWidget);
      final opacity = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(opacity.where((o) => o.opacity < 1.0), isEmpty);
    });
  });
}
