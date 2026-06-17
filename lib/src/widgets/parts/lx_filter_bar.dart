// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

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
        .where((l) => l.level == LayerXLogLevel.error || l.level == LayerXLogLevel.fatal)
        .length;
    final warningCount = allLogs.where((l) => l.level == LayerXLogLevel.warning).length;
    final successCount = allLogs.where((l) => l.level == LayerXLogLevel.success).length;
    final infoCount = allLogs.where((l) => l.level == LayerXLogLevel.info).length;
    final debugCount = allLogs.where((l) => l.level == LayerXLogLevel.debug).length;

    return Container(
      color: LxTheme.surface,
      child: Column(
        children: [
          // ── Top border ────────────────────────────────────────────────────
          Container(height: 1, color: LxTheme.border),

          const SizedBox(height: 10),

          // ── Level filters ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _pill('ALL', null, selectedLevel == null, LxTheme.accentBlue,
                    () => onLevelChanged(null)),
                _pill(
                  'ERR${errorCount > 0 ? ' $errorCount' : ''}',
                  null,
                  selectedLevel == LayerXLogLevel.error,
                  LxTheme.accentRed,
                  () => onLevelChanged(LayerXLogLevel.error),
                ),
                _pill(
                  'WARN${warningCount > 0 ? ' $warningCount' : ''}',
                  null,
                  selectedLevel == LayerXLogLevel.warning,
                  LxTheme.accentAmber,
                  () => onLevelChanged(LayerXLogLevel.warning),
                ),
                _pill(
                  'OK${successCount > 0 ? ' $successCount' : ''}',
                  null,
                  selectedLevel == LayerXLogLevel.success,
                  LxTheme.accentGreen,
                  () => onLevelChanged(LayerXLogLevel.success),
                ),
                _pill(
                  'INFO${infoCount > 0 ? ' $infoCount' : ''}',
                  null,
                  selectedLevel == LayerXLogLevel.info,
                  LxTheme.accentBlue,
                  () => onLevelChanged(LayerXLogLevel.info),
                ),
                _pill(
                  'DBG${debugCount > 0 ? ' $debugCount' : ''}',
                  null,
                  selectedLevel == LayerXLogLevel.debug,
                  LxTheme.accentPurple,
                  () => onLevelChanged(LayerXLogLevel.debug),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Source filters ────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _pill('ALL SOURCES', null, selectedSource == null,
                    LxTheme.textSecondary, () => onSourceChanged(null)),
                _pill('APP', null, selectedSource == LayerXLogSource.app,
                    LayerXLogSource.app.color, () => onSourceChanged(LayerXLogSource.app)),
                _pill('SERVER', null, selectedSource == LayerXLogSource.server,
                    LayerXLogSource.server.color,
                    () => onSourceChanged(LayerXLogSource.server)),
                _pill('BACKEND', null, selectedSource == LayerXLogSource.backend,
                    LayerXLogSource.backend.color,
                    () => onSourceChanged(LayerXLogSource.backend)),
                _pill('NETWORK', null, selectedSource == LayerXLogSource.network,
                    LayerXLogSource.network.color,
                    () => onSourceChanged(LayerXLogSource.network)),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Container(height: 1, color: LxTheme.border),
        ],
      ),
    );
  }

  Widget _pill(
    String label,
    int? count,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.6) : LxTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : LxTheme.textSecondary,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.6,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
