import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:layerx_debugger/src/widgets/lx_overlay_installer.dart';

/// Global test harness. Removes any debug-trigger overlay entry after each test
/// so `LayerXOverlayInstaller`'s static state never leaks between tests (a stale
/// entry would otherwise make later tests think the FAB is already installed).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(LayerXOverlayInstaller.reset);
  await testMain();
}
