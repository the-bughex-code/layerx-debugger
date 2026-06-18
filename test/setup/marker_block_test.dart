import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/util/marker_block.dart';

void main() {
  group('MarkerBlock', () {
    test('renderBlock wraps inner lines in begin/end markers', () {
      final out = MarkerBlock.renderBlock('x', ['a();', 'b();']);
      expect(out, contains('// layerx:begin(x)'));
      expect(out, contains('// layerx:end(x)'));
      expect(out, contains('a();'));
      expect(out, contains('b();'));
    });

    test('has detects an existing block', () {
      final src = MarkerBlock.renderBlock('x', ['a();']);
      expect(MarkerBlock.has(src, 'x'), isTrue);
      expect(MarkerBlock.has(src, 'y'), isFalse);
    });

    test('replaceBlock swaps inner content, leaving one block', () {
      final src = 'top\n${MarkerBlock.renderBlock('x', ['old();'])}\nbottom';
      final out = MarkerBlock.replaceBlock(src, 'x', ['new();'])!;
      expect(out, contains('new();'));
      expect(out, isNot(contains('old();')));
      expect('// layerx:begin(x)'.allMatches(out).length, 1);
    });

    test('replaceBlock returns null when block absent', () {
      expect(MarkerBlock.replaceBlock('nothing', 'x', ['a();']), isNull);
    });

    test('upsertImports inserts after last import, idempotent', () {
      const src = "import 'a.dart';\nimport 'b.dart';\n\nclass C {}";
      final once = MarkerBlock.upsertImports(src, ["import 'p.dart';"]);
      final twice = MarkerBlock.upsertImports(once, ["import 'p.dart';"]);
      expect(once, contains("import 'p.dart';"));
      expect(twice, equals(once));
      expect('// layerx:begin(import:layerx)'.allMatches(twice).length, 1);
    });
  });
}
