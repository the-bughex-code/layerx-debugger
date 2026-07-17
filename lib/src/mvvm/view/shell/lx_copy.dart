// lib/src/mvvm/view/shell/lx_copy.dart
// Internal viewer helper — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

/// The single copy path for the viewer: every copy action calls this, so the
/// clipboard behavior and confirmation wording are identical everywhere.
abstract final class LxCopy {
  static const String confirmation = 'Copied — paste it into your bug report';

  /// Copies [text] and shows exactly one confirmation snackbar. Rapid repeat
  /// copies replace the current snackbar instead of queueing behind it.
  ///
  /// `maybeOf`, not `of`: the FAB overlay works on Cupertino/WidgetsApp hosts
  /// that have no ScaffoldMessenger — the copy must still happen there, just
  /// without the confirmation.
  static Future<void> copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(LxTheme.snackBar(confirmation));
  }

  /// Copies the full session export, or explains there is nothing to copy.
  static Future<void> copyExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (LayerXLogStore.logs.isEmpty) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(LxTheme.snackBar('Nothing captured yet'));
      return;
    }
    final text = await LayerXLogStore.exportLogsAsString();
    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(LxTheme.snackBar(confirmation));
  }
}
