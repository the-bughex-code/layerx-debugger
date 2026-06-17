// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import '../../models/layerx_log_entry.dart';
import '../../models/layerx_log_level.dart';
import '../../models/layerx_log_source.dart';

class LxFilterBar extends StatelessWidget {
  final List<LayerXLogEntry> allLogs;
  final LayerXLogLevel? selectedLevel;
  final LayerXLogSource? selectedSource;
  final ValueChanged<LayerXLogLevel?> onLevelChanged;
  final ValueChanged<LayerXLogSource?> onSourceChanged;

  const LxFilterBar({
    super.key,
    required this.allLogs,
    required this.selectedLevel,
    required this.selectedSource,
    required this.onLevelChanged,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final errorCount = allLogs
        .where((l) =>
            l.level == LayerXLogLevel.error || l.level == LayerXLogLevel.fatal)
        .length;
    final warningCount =
        allLogs.where((l) => l.level == LayerXLogLevel.warning).length;
    final successCount =
        allLogs.where((l) => l.level == LayerXLogLevel.success).length;
    final infoCount =
        allLogs.where((l) => l.level == LayerXLogLevel.info).length;
    final debugCount =
        allLogs.where((l) => l.level == LayerXLogLevel.debug).length;

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _levelChip(
                  label: 'All',
                  isSelected: selectedLevel == null,
                  onSelected: () => onLevelChanged(null),
                  color: Colors.blueGrey,
                ),
                _levelChip(
                  label: 'Error${errorCount > 0 ? ' ($errorCount)' : ''}',
                  isSelected: selectedLevel == LayerXLogLevel.error,
                  onSelected: () => onLevelChanged(LayerXLogLevel.error),
                  color: LayerXLogLevel.error.color,
                ),
                _levelChip(
                  label: 'Warning${warningCount > 0 ? ' ($warningCount)' : ''}',
                  isSelected: selectedLevel == LayerXLogLevel.warning,
                  onSelected: () => onLevelChanged(LayerXLogLevel.warning),
                  color: LayerXLogLevel.warning.color,
                ),
                _levelChip(
                  label: 'Success${successCount > 0 ? ' ($successCount)' : ''}',
                  isSelected: selectedLevel == LayerXLogLevel.success,
                  onSelected: () => onLevelChanged(LayerXLogLevel.success),
                  color: LayerXLogLevel.success.color,
                ),
                _levelChip(
                  label: 'Info${infoCount > 0 ? ' ($infoCount)' : ''}',
                  isSelected: selectedLevel == LayerXLogLevel.info,
                  onSelected: () => onLevelChanged(LayerXLogLevel.info),
                  color: LayerXLogLevel.info.color,
                ),
                _levelChip(
                  label: 'Debug${debugCount > 0 ? ' ($debugCount)' : ''}',
                  isSelected: selectedLevel == LayerXLogLevel.debug,
                  onSelected: () => onLevelChanged(LayerXLogLevel.debug),
                  color: LayerXLogLevel.debug.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _sourceChip(
                  label: 'All Sources',
                  isSelected: selectedSource == null,
                  onSelected: () => onSourceChanged(null),
                  color: Colors.blueGrey,
                ),
                _sourceChip(
                  label: 'App',
                  isSelected: selectedSource == LayerXLogSource.app,
                  onSelected: () => onSourceChanged(LayerXLogSource.app),
                  color: LayerXLogSource.app.color,
                ),
                _sourceChip(
                  label: 'Server',
                  isSelected: selectedSource == LayerXLogSource.server,
                  onSelected: () => onSourceChanged(LayerXLogSource.server),
                  color: LayerXLogSource.server.color,
                ),
                _sourceChip(
                  label: 'Backend',
                  isSelected: selectedSource == LayerXLogSource.backend,
                  onSelected: () => onSourceChanged(LayerXLogSource.backend),
                  color: LayerXLogSource.backend.color,
                ),
                _sourceChip(
                  label: 'Network',
                  isSelected: selectedSource == LayerXLogSource.network,
                  onSelected: () => onSourceChanged(LayerXLogSource.network),
                  color: LayerXLogSource.network.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color color,
  }) =>
      _chip(label, isSelected, onSelected, color);

  Widget _sourceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color color,
  }) =>
      _chip(label, isSelected, onSelected, color);

  Widget _chip(
    String label,
    bool isSelected,
    VoidCallback onSelected,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade800,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
