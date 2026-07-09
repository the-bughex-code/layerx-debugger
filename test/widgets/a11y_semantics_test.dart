import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_console_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/lx_fab_trigger.dart';
import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

/// UX P4 · Task A — every icon-only / gesture-only control in the viewer must
/// expose a meaningful screen-reader label AND offer a ≥48×48 hit target.
/// These are the guard rails: labels are asserted with [find.bySemanticsLabel]
/// and hit areas with [WidgetTester.getSize].

LayerXLogEntry _entry(
  String id, {
  LayerXLogLevel level = LayerXLogLevel.error,
  DateTime? timestamp,
}) =>
    LayerXLogEntry(
      id: id,
      dedupKey: id,
      timestamp: timestamp ?? DateTime(2026, 1, 1, 10),
      level: level,
      source: LayerXLogSource.app,
      category: LayerXLogCategory.app,
      message: id,
      journey: const [],
      extras: const {},
    );

/// Steps a route transition to its terminal frame in small discrete pumps so
/// the pushed detail route actually paints (a single large pump can leave the
/// barrier hit-testable on top). Mirrors detail_copy_nav_test's harness.
Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  group('FAB trigger', () {
    setUp(() {
      LayerXOverlayInstaller.reset();
      LayerXViewerState.isOpen.value = false;
    });
    tearDown(() {
      LayerXOverlayInstaller.reset();
      LayerXViewerState.isOpen.value = false;
    });

    testWidgets(
        'is a labeled button ("Report a bug — open the debugger") with a '
        '≥48dp pill', (tester) async {
      final handle = tester.ensureSemantics();

      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
      LayerXOverlayInstaller.installInto(overlay);
      await tester.pump(); // deferred post-frame insert
      await tester.pump(const Duration(milliseconds: 600)); // settle mount anim

      expect(find.byType(LxFabTrigger), findsOneWidget);

      final fab = find.bySemanticsLabel('Report a bug — open the debugger');
      expect(fab, findsOneWidget);
      // Pill is exactly 48 tall — assert the a11y floor holds.
      expect(tester.getSize(fab).height, greaterThanOrEqualTo(48.0));

      handle.dispose();
    });
  });

  group('Console controls', () {
    testWidgets('per-row copy is labeled "Copy this log" with a ≥48×48 target',
        (tester) async {
      final handle = tester.ensureSemantics();

      final e = _entry('copy me');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LxConsolePane(logs: [e], onInspect: (_) {})),
      ));
      // Let the row's staggered entrance finish: while it is still fully
      // transparent (opacity 0) RenderOpacity drops the subtree from the
      // semantics tree, so the label would not resolve yet.
      await tester.pump(const Duration(milliseconds: 400));

      final copy = find.bySemanticsLabel('Copy this log');
      expect(copy, findsOneWidget);

      final size = tester.getSize(copy);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      handle.dispose();
    });

    testWidgets(
        'level filter funnel keeps its tooltip and has a ≥48×48 tap target',
        (tester) async {
      final e = _entry('anything');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LxConsolePane(logs: [e], onInspect: (_) {})),
      ));
      await tester.pump();

      // Tooltip retained — it is the funnel's screen-reader hint.
      expect(find.byTooltip('Filter by level'), findsOneWidget);

      // The 48×48 box tightly sizes the inner PopupMenuButton's IconButton, so
      // the tappable funnel clears the a11y floor even though its glyph is 18dp.
      final funnel = find.byType(PopupMenuButton<LayerXLogLevel?>);
      expect(funnel, findsOneWidget);
      final size = tester.getSize(funnel);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('Shell + pushed detail', () {
    setUp(LayerXLogStore.clear);
    tearDown(LayerXLogStore.clear);

    testWidgets(
        'shell exposes "Copy full report"; a pushed detail exposes labeled '
        '"Previous problem" / "Next problem" IconButtons ≥48dp',
        (tester) async {
      final handle = tester.ensureSemantics();

      // Three problems so tapping the middle-ranked one leaves BOTH chevrons
      // enabled (index 1 of 3).
      LayerXLogStore.add(
          _entry('alpha problem', timestamp: DateTime(2026, 1, 1, 10, 0, 2)));
      LayerXLogStore.add(
          _entry('bravo problem', timestamp: DateTime(2026, 1, 1, 10, 0, 1)));
      LayerXLogStore.add(
          _entry('charlie problem', timestamp: DateTime(2026, 1, 1, 10, 0, 0)));

      await tester.pumpWidget(const MaterialApp(home: LxDebuggerShell()));
      await tester.pump(const Duration(milliseconds: 400));

      // App-bar export control (icon-only) is reachable by its label.
      expect(find.bySemanticsLabel('Copy full report'), findsOneWidget);

      await tester.tap(find.text('bravo problem'));
      await _pumpFrames(tester, const Duration(milliseconds: 400));

      final prev = find.bySemanticsLabel('Previous problem');
      final next = find.bySemanticsLabel('Next problem');
      expect(prev, findsOneWidget);
      expect(next, findsOneWidget);

      final prevSize = tester.getSize(prev);
      final nextSize = tester.getSize(next);
      expect(prevSize.width, greaterThanOrEqualTo(48.0));
      expect(prevSize.height, greaterThanOrEqualTo(48.0));
      expect(nextSize.width, greaterThanOrEqualTo(48.0));
      expect(nextSize.height, greaterThanOrEqualTo(48.0));

      handle.dispose();
    });
  });
}
