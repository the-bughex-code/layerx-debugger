import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';

/// Shared, app-wide state for the in-app debugger viewer.
///
/// Tracks whether the debugger shell is currently open (so the floating button
/// can hide itself and avoid overlay conflicts) and which log entry the
/// Inspector pane is focused on.
abstract final class LayerXViewerState {
  /// True while the debugger shell is on screen. The overlay hides the FAB and
  /// edge trigger while this is true to prevent duplicate/overlapping UI.
  static final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  /// The log entry currently selected for inspection, if any.
  static final ValueNotifier<LayerXLogEntry?> selected =
      ValueNotifier<LayerXLogEntry?>(null);

  /// Marks the viewer open. Called by the shell on mount.
  static void markOpened() => _run(() => isOpen.value = true);

  /// Marks the viewer closed and clears the selection. Called on shell dispose.
  static void markClosed() => _run(() {
        isOpen.value = false;
        selected.value = null;
      });

  /// Runs [fn], deferring to after the current frame when we are mid-build.
  ///
  /// The shell calls [markOpened] from its `initState`, which can run *during*
  /// the overlay's build (when the FAB pushes the shell). Flipping [isOpen]
  /// synchronously there would `markNeedsBuild` the trigger layer that listens
  /// to it while the framework is already building — a hard error. Deferring one
  /// frame in that case keeps the state change safe and imperceptible.
  static void _run(VoidCallback fn) {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => fn());
    } else {
      fn();
    }
  }
}
