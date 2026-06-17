import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  group('LayerXMasker', () {
    test('masks sensitive keys recursively and case-insensitively', () {
      final masked = LayerXMasker.mask({
        'username': 'bob',
        'Password': '123',
        'data': {
          'token': 'abc',
          'nested': [
            {'secret': 's'},
          ],
        },
      }) as Map;

      expect(masked['username'], 'bob');
      expect(masked['Password'], '********');
      expect((masked['data'] as Map)['token'], '********');
      final nested = ((masked['data'] as Map)['nested'] as List).first as Map;
      expect(nested['secret'], '********');
    });

    test('masks headers including extra keys', () {
      final masked = LayerXMasker.maskHeaders(
        {'Authorization': 'Bearer x', 'X-Custom': 'y'},
        extraKeys: ['x-custom'],
      );
      expect(masked['Authorization'], '********');
      expect(masked['X-Custom'], '********');
    });

    test('maskJsonString masks and pretty-prints valid JSON', () {
      final out = LayerXMasker.maskJsonString('{"token":"abc","keep":1}');
      expect(out, contains('********'));
      expect(out, contains('keep'));
    });

    test('maskJsonString passes through non-JSON unchanged', () {
      expect(LayerXMasker.maskJsonString('not json'), 'not json');
    });
  });
}
