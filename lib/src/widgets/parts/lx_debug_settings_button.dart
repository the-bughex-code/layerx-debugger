import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_debugger_shell.dart';

/// A ready-made list tile that opens the LayerX log viewer.
///
/// Drop it into your own settings/debug screen to give testers an entry point
/// to the in-app logs without using the floating button:
///
/// ```dart
/// ListView(children: const [LayerXDebugSettingsButton()]);
/// ```
class LayerXDebugSettingsButton extends StatelessWidget {
  /// Creates the settings entry tile.
  const LayerXDebugSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LayerXLogEntry>>(
      valueListenable: LayerXLogStore.logsNotifier,
      builder: (context, logs, _) {
        final errorCount = LayerXLogStore.errorCount;
        final totalCount = logs.length;

        return ListTile(
          leading:
              const Icon(Icons.bug_report_outlined, color: Colors.blueGrey),
          title: const Text(
            'LayerX Debug Logger',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$totalCount logs • $errorCount errors'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LxDebuggerShell(),
              ),
            );
          },
        );
      },
    );
  }
}
