import 'package:flutter/foundation.dart';

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
  static void markOpened() => isOpen.value = true;

  /// Marks the viewer closed and clears the selection. Called on shell dispose.
  static void markClosed() {
    isOpen.value = false;
    selected.value = null;
  }
}
