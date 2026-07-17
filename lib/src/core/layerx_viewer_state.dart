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

  static int _openShells = 0;
  static bool _openPending = false;

  /// Claims the exclusive right to push the debugger shell.
  ///
  /// Every open path (FAB tap, coach bubble, quick menu, edge swipe,
  /// `LayerXDebugger.openViewer`, the settings tile) must call this before
  /// pushing and back off on `false`. Without it a double-tap or a swipe
  /// that fires several drag updates pushes several stacked shells, and the
  /// back button then appears broken. The claim is released when the shell
  /// mounts ([markOpened]); callers whose push fails must release it
  /// themselves via [cancelOpen].
  static bool beginOpen() {
    if (_openShells > 0 || _openPending) return false;
    _openPending = true;
    // Failsafe: if the push never materializes a shell (dead navigator, a
    // locked route table), release the claim after two frames so the viewer
    // cannot be bricked for the rest of the session.
    try {
      final binding = SchedulerBinding.instance;
      binding.addPostFrameCallback((_) {
        binding.addPostFrameCallback((_) {
          if (_openShells == 0) _openPending = false;
        });
      });
      binding.ensureVisualUpdate();
    } catch (_) {
      // No binding — nothing will mount a shell either; keep the sync guard.
    }
    return true;
  }

  /// Releases a [beginOpen] claim whose push failed before the shell mounted.
  static void cancelOpen() => _openPending = false;

  /// Marks the viewer open. Called by the shell on mount.
  static void markOpened() {
    _openPending = false;
    _openShells++;
    _run(() => isOpen.value = true);
  }

  /// Marks the viewer closed and clears the selection. Called on shell dispose.
  static void markClosed() {
    if (_openShells > 0) _openShells--;
    if (_openShells > 0) return;
    _run(() {
      isOpen.value = false;
      selected.value = null;
    });
  }

  /// Resets the open-guard bookkeeping. Intended for tests and hot-restart.
  static void reset() {
    _openShells = 0;
    _openPending = false;
    isOpen.value = false;
    selected.value = null;
  }

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
