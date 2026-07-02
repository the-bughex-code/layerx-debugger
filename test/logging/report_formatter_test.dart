import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_report_formatter.dart';

LayerXLogEntry _entry({
  LayerXLogLevel level = LayerXLogLevel.error,
  String message = 'API Error: 500 on /users',
  int? statusCode = 500,
  String? endpoint = 'https://api.x.com/users',
  String? request = '{"id":1}',
  String? response = '{"error":"boom"}',
  String? stack = '#0 main (a.dart:1:1)',
}) =>
    LayerXLogEntry(
      id: '1', dedupKey: 'k',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      level: level, source: LayerXLogSource.server, message: message,
      endpoint: endpoint, statusCode: statusCode,
      requestPayload: request, responsePayload: response, stackTrace: stack,
      journey: const [], extras: const {},
    );

void main() {
  test('a 500 error report contains every section in plain language', () {
    final report = LayerXReportFormatter.formatIssue(_entry());
    expect(report, contains('API Error: 500 on /users')); // title
    expect(report, contains('Server Error')); // source.label (friendly)
    expect(report, contains('500')); // status
    expect(report, contains('5m ago')); // relative time
    expect(report, contains('{"id":1}')); // request
    expect(report, contains('{"error":"boom"}')); // response
    expect(report, contains('Assign to')); // blame qaNote for a 5xx
    expect(report, contains('#0 main')); // stack
    // Ordering: request appears before response, stack is last.
    expect(report.indexOf('{"id":1}'), lessThan(report.indexOf('{"error":"boom"}')));
    expect(report.indexOf('#0 main'), greaterThan(report.indexOf('Assign to')));
  });

  test('an info entry has no blame section and no stack heading', () {
    final report = LayerXReportFormatter.formatIssue(_entry(
      level: LayerXLogLevel.info,
      message: 'hello',
      statusCode: null,
      endpoint: null,
      request: null,
      response: null,
      stack: null,
    ));
    expect(report, contains('hello'));
    expect(report, isNot(contains('Assign to')));
    expect(report, isNot(contains('Stack trace')));
  });

  test('relative time says "just now" for fresh entries', () {
    final e = _entry();
    final fresh = e.copyWith(timestamp: DateTime.now());
    expect(LayerXReportFormatter.formatIssue(fresh), contains('just now'));
  });
}
