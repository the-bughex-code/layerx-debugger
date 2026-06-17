// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_filter_bar.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_log_tile.dart';
import 'package:layerx_debugger/src/mvvm/view/lx_log_detail_screen.dart';

class LxLogListScreen extends StatefulWidget {
  const LxLogListScreen({super.key});

  @override
  State<LxLogListScreen> createState() => _LxLogListScreenState();
}

class _LxLogListScreenState extends State<LxLogListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  LayerXLogLevel? _selectedLevel;
  LayerXLogSource? _selectedSource;
  bool _showStatsBanner = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LayerXLogEntry>>(
      valueListenable: LayerXLogStore.logsNotifier,
      builder: (context, allLogs, _) {
        final filteredLogs = _applyFilters(allLogs);

        final totalCount = allLogs.length;
        final errorCount = allLogs
            .where((log) =>
                log.level == LayerXLogLevel.error ||
                log.level == LayerXLogLevel.fatal)
            .length;
        final warningCount =
            allLogs.where((l) => l.level == LayerXLogLevel.warning).length;
        final apiChangedCount = allLogs.where((l) => l.responseChanged).length;
        final schemaChangeTotal =
            allLogs.fold<int>(0, (sum, l) => sum + l.schemaChanges.length);

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: _buildAppBar(totalCount, errorCount),
          body: Column(
            children: [
              if (allLogs.isNotEmpty && _showStatsBanner)
                _buildStatsBanner(
                  total: totalCount,
                  errors: errorCount,
                  warnings: warningCount,
                  apiChanged: apiChangedCount,
                  schemaChanges: schemaChangeTotal,
                ),
              LxFilterBar(
                allLogs: allLogs,
                selectedLevel: _selectedLevel,
                selectedSource: _selectedSource,
                onLevelChanged: (level) =>
                    setState(() => _selectedLevel = level),
                onSourceChanged: (source) =>
                    setState(() => _selectedSource = source),
              ),
              Expanded(child: _buildLogList(filteredLogs, allLogs.isEmpty)),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(int totalCount, int errorCount) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.black87),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search logs...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              onChanged: (val) => setState(() => _searchQuery = val),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🐛 LayerX Logger',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${LayerXDebugger.config.appName} • $totalCount logs • $errorCount errors',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          )
        else
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true),
          ),
        IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          tooltip: 'Export All Logs',
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await LayerXLogStore.copyExportToClipboard();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('All logs exported & copied to clipboard! 📋'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        IconButton(
          icon:
              const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          tooltip: 'Clear All',
          onPressed: () => _confirmClear(context),
        ),
      ],
    );
  }

  Widget _buildStatsBanner({
    required int total,
    required int errors,
    required int warnings,
    required int apiChanged,
    required int schemaChanges,
  }) {
    final String healthLabel;
    final Color healthColor;
    final IconData healthIcon;
    final Color bgColor;

    if (errors > 0) {
      healthLabel = 'Issues Detected';
      healthColor = Colors.red.shade800;
      healthIcon = Icons.error_outline;
      bgColor = const Color(0xFFFFF1F1);
    } else if (warnings > 0 || apiChanged > 0) {
      healthLabel = 'Warnings Present';
      healthColor = Colors.orange.shade800;
      healthIcon = Icons.warning_amber_outlined;
      bgColor = const Color(0xFFFFF8EE);
    } else {
      healthLabel = 'All Clear';
      healthColor = const Color(0xFF2E7D32);
      healthIcon = Icons.check_circle_outline;
      bgColor = const Color(0xFFF1FAF1);
    }

    return GestureDetector(
      onTap: () => setState(() => _showStatsBanner = !_showStatsBanner),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: healthColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(healthIcon, color: healthColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'SESSION HEALTH: $healthLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: healthColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_less,
                    size: 14, color: healthColor.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(
                  value: total.toString(),
                  label: 'Total',
                  color: Colors.blueGrey.shade700,
                  bg: Colors.blueGrey.shade50,
                ),
                const SizedBox(width: 6),
                _statChip(
                  value: errors.toString(),
                  label: 'Errors',
                  color:
                      errors > 0 ? Colors.red.shade800 : Colors.grey.shade500,
                  bg: errors > 0 ? Colors.red.shade50 : Colors.grey.shade100,
                ),
                const SizedBox(width: 6),
                _statChip(
                  value: warnings.toString(),
                  label: 'Warnings',
                  color: warnings > 0
                      ? Colors.orange.shade800
                      : Colors.grey.shade500,
                  bg: warnings > 0
                      ? Colors.orange.shade50
                      : Colors.grey.shade100,
                ),
                const SizedBox(width: 6),
                if (apiChanged > 0)
                  _statChip(
                    value: apiChanged.toString(),
                    label: 'API Changed',
                    color: Colors.orange.shade800,
                    bg: Colors.orange.shade50,
                    icon: Icons.swap_horiz,
                  ),
                if (schemaChanges > 0) ...[
                  const SizedBox(width: 6),
                  _statChip(
                    value: schemaChanges.toString(),
                    label: 'Schema Diffs',
                    color: const Color(0xFF6A1B9A),
                    bg: const Color(0xFFF3E5F5),
                    icon: Icons.data_object_outlined,
                  ),
                ],
              ],
            ),
            if (errors > 0 || apiChanged > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 6),
              _buildAttributionHints(errors: errors, apiChanged: apiChanged),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip({
    required String value,
    required String label,
    required Color color,
    required Color bg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionHints(
      {required int errors, required int apiChanged}) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (errors > 0)
          _hintChip(
            '🔍 Tap a red log → "WHO OWNS THIS BUG?" for team attribution',
            Colors.red.shade800,
            const Color(0xFFFFEBEE),
          ),
        if (apiChanged > 0)
          _hintChip(
            '🔄 $apiChanged endpoint${apiChanged > 1 ? 's' : ''} changed — tap orange badge to see diff',
            Colors.orange.shade800,
            const Color(0xFFFFF3E0),
          ),
      ],
    );
  }

  Widget _hintChip(String text, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildLogList(List<LayerXLogEntry> filteredLogs, bool isStoreEmpty) {
    if (isStoreEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Interact with the app to generate logs.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No logs match this filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: _clearFilters,
              child: const Text('Clear Filter'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredLogs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return LxLogTile(
          log: log,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => LxLogDetailScreen(log: log),
              ),
            );
          },
          onDelete: () => LayerXLogStore.deleteLog(log.id),
        );
      },
    );
  }

  List<LayerXLogEntry> _applyFilters(List<LayerXLogEntry> allLogs) {
    return allLogs.where((log) {
      if (_selectedLevel != null) {
        if (_selectedLevel == LayerXLogLevel.error) {
          if (log.level != LayerXLogLevel.error &&
              log.level != LayerXLogLevel.fatal) {
            return false;
          }
        } else if (log.level != _selectedLevel) {
          return false;
        }
      }

      if (_selectedSource != null && log.source != _selectedSource) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = log.message.toLowerCase().contains(q) ||
            (log.screenName ?? '').toLowerCase().contains(q) ||
            (log.methodName ?? '').toLowerCase().contains(q) ||
            (log.endpoint ?? '').toLowerCase().contains(q) ||
            (log.errorCode ?? '').toLowerCase().contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedLevel = null;
      _selectedSource = null;
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
          'This will clear the current in-memory log database and all response history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              LayerXLogStore.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
