// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/core/layerx_debugger_initializer.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_filter_bar.dart';
import 'package:layerx_debugger/src/widgets/parts/lx_log_tile.dart';
import 'package:layerx_debugger/src/mvvm/view/lx_log_detail_screen.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

class LxLogListScreen extends StatefulWidget {
  const LxLogListScreen({super.key});

  @override
  State<LxLogListScreen> createState() => _LxLogListScreenState();
}

class _LxLogListScreenState extends State<LxLogListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  LayerXLogLevel? _selectedLevel;
  LayerXLogSource? _selectedSource;

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ValueListenableBuilder<List<LayerXLogEntry>>(
        valueListenable: LayerXLogStore.logsNotifier,
        builder: (context, allLogs, _) {
          final filteredLogs = _applyFilters(allLogs);
          final errorCount = allLogs
              .where((l) =>
                  l.level == LayerXLogLevel.error ||
                  l.level == LayerXLogLevel.fatal)
              .length;
          final warningCount =
              allLogs.where((l) => l.level == LayerXLogLevel.warning).length;
          final apiChanged =
              allLogs.where((l) => l.responseChanged).length;

          return Scaffold(
            backgroundColor: LxTheme.bg,
            appBar: _buildAppBar(allLogs.length, errorCount),
            body: Column(
              children: [
                // ── Stats bar ──────────────────────────────────────────────
                if (allLogs.isNotEmpty)
                  FadeTransition(
                    opacity: _headerAnim,
                    child: _buildStatsBar(
                      total: allLogs.length,
                      errors: errorCount,
                      warnings: warningCount,
                      apiChanged: apiChanged,
                    ),
                  ),

                // ── Filter bar ─────────────────────────────────────────────
                LxFilterBar(
                  allLogs: allLogs,
                  selectedLevel: _selectedLevel,
                  selectedSource: _selectedSource,
                  onLevelChanged: (l) => setState(() => _selectedLevel = l),
                  onSourceChanged: (s) => setState(() => _selectedSource = s),
                ),

                // ── Log list ───────────────────────────────────────────────
                Expanded(
                  child: _buildLogList(filteredLogs, allLogs.isEmpty),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(int total, int errors) {
    return AppBar(
      backgroundColor: LxTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: LxTheme.textSecondary, size: 20),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: LxTheme.border),
      ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: LxTheme.mono.copyWith(fontSize: 14),
              cursorColor: LxTheme.accentBlue,
              decoration: InputDecoration(
                hintText: '> search logs...',
                hintStyle: LxTheme.mono.copyWith(
                  color: LxTheme.textDim,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Live pulse dot
                    _pulseDot(errors > 0 ? LxTheme.accentRed : LxTheme.accentGreen),
                    const SizedBox(width: 8),
                    Text(
                      'LAYERX DEBUGGER',
                      style: LxTheme.sectionLabel.copyWith(
                        fontSize: 13,
                        color: LxTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${LayerXDebugger.config.appName}  ·  $total logs  ·  $errors errors',
                  style: LxTheme.monoSm,
                ),
              ],
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            }),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => setState(() => _isSearching = true),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            tooltip: 'Export All',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await LayerXLogStore.copyExportToClipboard();
              messenger.showSnackBar(LxTheme.snackBar('Logs copied to clipboard ✓'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: LxTheme.accentRed),
            tooltip: 'Clear All',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ],
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar({
    required int total,
    required int errors,
    required int warnings,
    required int apiChanged,
  }) {
    final healthColor = errors > 0
        ? LxTheme.accentRed
        : warnings > 0
            ? LxTheme.accentAmber
            : LxTheme.accentGreen;

    final healthLabel = errors > 0
        ? 'ISSUES DETECTED'
        : warnings > 0
            ? 'WARNINGS'
            : 'ALL CLEAR';

    return Container(
      color: LxTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Health indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: healthColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: healthColor,
                    shape: BoxShape.circle,
                    boxShadow: LxTheme.glowShadow(healthColor, spread: 2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  healthLabel,
                  style: TextStyle(
                    color: healthColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statItem(total.toString(), 'TOTAL', LxTheme.accentBlue),
          const SizedBox(width: 10),
          if (errors > 0) _statItem(errors.toString(), 'ERR', LxTheme.accentRed),
          if (errors > 0) const SizedBox(width: 10),
          if (warnings > 0) _statItem(warnings.toString(), 'WARN', LxTheme.accentAmber),
          if (warnings > 0) const SizedBox(width: 10),
          if (apiChanged > 0) _statItem(apiChanged.toString(), 'API Δ', LxTheme.accentOrange),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            height: 1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _pulseDot(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: v),
          boxShadow: [BoxShadow(color: color.withValues(alpha: v * 0.6), blurRadius: 6)],
        ),
      ),
      onEnd: () => setState(() {}), // retrigger
    );
  }

  // ── Log list ───────────────────────────────────────────────────────────────
  Widget _buildLogList(List<LayerXLogEntry> filteredLogs, bool isEmpty) {
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LxTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LxTheme.border),
              ),
              child: const Icon(Icons.terminal, size: 40, color: LxTheme.textDim),
            ),
            const SizedBox(height: 20),
            const Text('NO LOGS YET', style: LxTheme.sectionLabel),
            const SizedBox(height: 8),
            Text(
              'Interact with the app to generate logs.',
              style: LxTheme.bodySecondary,
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
            const Icon(Icons.filter_list_off, size: 40, color: LxTheme.textDim),
            const SizedBox(height: 16),
            const Text('NO MATCHES', style: LxTheme.sectionLabel),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: LxTheme.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LxTheme.accentBlue.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'CLEAR FILTERS',
                  style: LxTheme.sectionLabel.copyWith(color: LxTheme.accentBlue),
                ),
              ),
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
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (_, a, __) => LxLogDetailScreen(log: log),
              transitionsBuilder: (_, a, __, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
          onDelete: () => LayerXLogStore.deleteLog(log.id),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<LayerXLogEntry> _applyFilters(List<LayerXLogEntry> all) {
    return all.where((log) {
      if (_selectedLevel != null) {
        if (_selectedLevel == LayerXLogLevel.error) {
          if (log.level != LayerXLogLevel.error && log.level != LayerXLogLevel.fatal) {
            return false;
          }
        } else if (log.level != _selectedLevel) {
          return false;
        }
      }
      if (_selectedSource != null && log.source != _selectedSource) return false;
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

  void _clearFilters() => setState(() {
        _selectedLevel = null;
        _selectedSource = null;
        _searchQuery = '';
        _isSearching = false;
        _searchController.clear();
      });

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: LxTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LxTheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: LxTheme.accentRed, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'CLEAR ALL LOGS',
                    style: LxTheme.sectionLabel.copyWith(color: LxTheme.accentRed),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This will clear all in-memory logs and response history.\nThis action cannot be undone.',
                style: LxTheme.bodySecondary,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Cancel', style: LxTheme.bodySecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      LayerXLogStore.clear();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: LxTheme.accentRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: LxTheme.accentRed.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Clear',
                        style: LxTheme.labelBold.copyWith(color: LxTheme.accentRed),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
