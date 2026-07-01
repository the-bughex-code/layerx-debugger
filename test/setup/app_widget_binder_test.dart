import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/integration/app_widget_binder.dart';

void main() {
  group('bindAppWidget', () {
    test('injects builder + navigatorObservers when neither is present', () {
      const src = '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  Widget build(context) {
    return MaterialApp(
      title: 'x',
      home: Home(),
    );
  }
}
''';
      final res = bindAppWidget(src)!;
      expect(res.builderSkipped, isFalse);
      expect(res.source,
          contains('builder: (context, child) => LayerXDebugOverlay('));
      expect(res.source,
          contains('navigatorObservers: [LayerXDebugger.routeObserver]'));
      expect(res.source, contains('package:layerx_debugger/layerx_debugger.dart'));
    });

    test('does NOT add a second builder when the app already has one', () {
      const src = '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class App extends StatelessWidget {
  Widget build(context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaleFactor: 1.0), child: child!);
      },
      title: 'x',
    );
  }
}
''';
      final res = bindAppWidget(src)!;
      // Exactly one builder: — the app's own. No duplicate named arg.
      expect(RegExp(r'\bbuilder\s*:').allMatches(res.source).length, 1);
      // Observers are still added (they were absent).
      expect(res.source,
          contains('navigatorObservers: [LayerXDebugger.routeObserver]'));
      // Flag tells the caller a manual overlay wrap is needed.
      expect(res.builderSkipped, isTrue);
    });

    test('does NOT duplicate navigatorObservers when already present', () {
      const src = '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  Widget build(context) {
    return MaterialApp(
      navigatorObservers: [myObserver],
      home: Home(),
    );
  }
}
''';
      final res = bindAppWidget(src)!;
      expect(RegExp(r'\bnavigatorObservers\s*:').allMatches(res.source).length, 1);
      // Builder was absent, so it is still injected.
      expect(res.source,
          contains('builder: (context, child) => LayerXDebugOverlay('));
    });

    test('returns null when no MaterialApp/GetMaterialApp is present', () {
      expect(bindAppWidget('class X {}'), isNull);
    });

    test('returns null when already wrapped with LayerXDebugOverlay', () {
      const src = '''
class App {
  build() => MaterialApp(
    builder: (context, child) => LayerXDebugOverlay(child: child!),
    home: Home(),
  );
}
''';
      expect(bindAppWidget(src), isNull);
    });
  });
}
