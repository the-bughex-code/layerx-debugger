// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/mvvm/view/lx_log_list_screen.dart';

class LxFabTrigger extends StatefulWidget {
  const LxFabTrigger({super.key});

  @override
  State<LxFabTrigger> createState() => _LxFabTriggerState();
}

class _LxFabTriggerState extends State<LxFabTrigger> {
  Offset _offset = const Offset(-1, -1);
  bool _isHovered = false;
  bool _isDragging = false;

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LxLogListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (_offset.dx == -1 && _offset.dy == -1) {
      _offset = Offset(screenSize.width - 70, screenSize.height - 140);
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: ValueListenableBuilder<List<LayerXLogEntry>>(
        valueListenable: LayerXLogStore.logsNotifier,
        builder: (context, logs, _) {
          final errorCount = LayerXLogStore.errorCount;
          final totalCount = logs.length;
          final hasErrors = errorCount > 0;
          final badgeCount = hasErrors ? errorCount : totalCount;

          return MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  var newX = _offset.dx + details.delta.dx;
                  var newY = _offset.dy + details.delta.dy;
                  newX = newX.clamp(10.0, screenSize.width - 70.0);
                  newY = newY.clamp(50.0, screenSize.height - 100.0);
                  _offset = Offset(newX, newY);
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              onTap: () => _openLogs(context),
              onLongPress: () => _showLongPressMenu(context),
              child: Opacity(
                opacity: (_isHovered || _isDragging) ? 1.0 : 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: hasErrors
                            ? Colors.red.shade900
                            : Colors.blueGrey.shade800,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bug_report,
                          color: Colors.white, size: 26),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hasErrors ? Colors.red : Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.blueGrey),
                title: const Text('View Logs'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openLogs(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.green),
                title: const Text('Export & Copy all'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  await LayerXLogStore.copyExportToClipboard();
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('All logs copied to clipboard! 📋')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text('Clear All'),
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  LayerXLogStore.clear();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Logs cleared!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
