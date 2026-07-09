import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/services/logger/layerx_log_output.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';

/// Regression tests for stack-frame attribution in [LayerXLogOutput].
///
/// The SDK-frame filter used to skip *every* real app frame because a normal
/// frame path (e.g. `package:myapp/home_controller.dart:42`) contains the
/// substring `dart:`. These assert that `class.method` attribution survives on
/// the `packageName == null` path while true SDK/framework frames are skipped.
void main() {
  setUp(LayerXLogStore.clear);

  test('attributes screen and method from the first app frame', () {
    final trace = StackTrace.fromString(
      '#0      MyController.load (package:myapp/home_controller.dart:42:11)\n'
      '#1      main (package:myapp/main.dart:5:3)\n',
    );

    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'loaded',
      stackTrace: trace,
    );

    final entry = LayerXLogStore.logs.first;
    expect(entry.screenName, 'MyController');
    expect(entry.methodName, 'load');
  });

  test('skips true SDK (dart:) frames and lands on the first app frame', () {
    final trace = StackTrace.fromString(
      '#0      List.[] (dart:core-patch/growable_array.dart:264:36)\n'
      '#1      HomeController.load (package:myapp/home_controller.dart:42:11)\n',
    );

    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'loaded',
      stackTrace: trace,
    );

    final entry = LayerXLogStore.logs.first;
    expect(entry.screenName, 'HomeController');
    expect(entry.methodName, 'load');
  });

  test('skips flutter framework frames and lands on the first app frame', () {
    final trace = StackTrace.fromString(
      '#0      State.setState (package:flutter/src/widgets/framework.dart:1180:14)\n'
      '#1      ProfileView.build (package:myapp/profile_view.dart:88:7)\n',
    );

    LayerXLogOutput.ingest(
      level: LayerXLogLevel.info,
      message: 'built',
      stackTrace: trace,
    );

    final entry = LayerXLogStore.logs.first;
    expect(entry.screenName, 'ProfileView');
    expect(entry.methodName, 'build');
  });
}
