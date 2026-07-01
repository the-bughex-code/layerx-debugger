import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/steps/verify_step.dart';

void main() {
  group('revertUnparseableFiles', () {
    test('reverts a file that no longer parses, restoring its .bak', () async {
      final dir = Directory.systemTemp.createTempSync('layerx_guard');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/broken.dart';
      // The .bak holds the valid original the CLI backed up before editing.
      File('$path.bak').writeAsStringSync('class A {\n  final x = 1;\n}\n');
      // The current file is what a bad injection produced: a bare statement in
      // the class body — invalid Dart.
      File(path).writeAsStringSync(
        'class A {\n  final x = 1;\n  x.doThing();\n}\n',
      );

      final reverted = await revertUnparseableFiles(dir.path, [path]);

      expect(reverted, [path]);
      final restored = File(path).readAsStringSync();
      expect(restored, isNot(contains('x.doThing();')));
      expect(restored, contains('final x = 1;'));
    });

    test('leaves a file that parses cleanly untouched', () async {
      final dir = Directory.systemTemp.createTempSync('layerx_guard');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/ok.dart';
      const good = 'class A {\n  final x = 1;\n}\n';
      File('$path.bak').writeAsStringSync('class A {}\n');
      File(path).writeAsStringSync(good);

      final reverted = await revertUnparseableFiles(dir.path, [path]);

      expect(reverted, isEmpty);
      expect(File(path).readAsStringSync(), good);
    });

    test('does not revert a broken file when no .bak exists', () async {
      final dir = Directory.systemTemp.createTempSync('layerx_guard');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/broken.dart';
      const broken = 'class A {\n  x.doThing();\n}\n';
      File(path).writeAsStringSync(broken);

      final reverted = await revertUnparseableFiles(dir.path, [path]);

      // Nothing to restore from — leave it and let analyze report it.
      expect(reverted, isEmpty);
      expect(File(path).readAsStringSync(), broken);
    });
  });
}
