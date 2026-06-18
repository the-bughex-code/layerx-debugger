import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bin/src/integration/integration_scanner.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lx_scan'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(String rel, String content) {
    final f = File('${tmp.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  test('detects logger by static final Logger field', () {
    write('lib/app/services/logger_service.dart',
        'class LoggerService { static final Logger _l = Logger(); }');
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.logger.found, isTrue);
    expect(t.logger.className, 'LoggerService');
  });

  test('detects dio instantiation and http wrapper', () {
    write('lib/app/services/net.dart', 'var d = Dio();');
    write('lib/app/services/https_calls.dart',
        "import 'package:http/http.dart' as http;\nclass HttpsCalls { void f() { http.get(); } }");
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.dio.found, isTrue);
    expect(t.httpWrap.found, isTrue);
    expect(t.httpWrap.className, 'HttpsCalls');
  });

  test('reports notFound when nothing matches', () {
    write('lib/app/services/empty.dart', 'class Empty {}');
    final t = IntegrationScanner(tmp.path).scan();
    expect(t.logger.found, isFalse);
    expect(t.dio.found, isFalse);
    expect(t.httpWrap.found, isFalse);
  });
}
