// Internal viewer screen — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/core/layerx_viewer_state.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_copy.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_everything_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_inspector_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_problems_pane.dart';
import 'package:layerx_debugger/src/mvvm/view/shell/lx_ui_kit.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';
import 'package:layerx_debugger/src/repository/layerx_report_formatter.dart';

enum _LxSegment { problems, everything }

/// The redesigned in-app debugger: a two-segment shell — **Problems** (the
/// worst-first inbox testers land on) and **Everything** (the full Console /
/// Network / Dashboard, one tap behind). Tapping any row pushes a Details
/// route hosting the Inspector, and a labeled Done closes the viewer.
class LxDebuggerShell extends StatefulWidget {
  const LxDebuggerShell({super.key});

  @override
  State<LxDebuggerShell> createState() => _LxDebuggerShellState();
}

class _LxDebuggerShellState extends State<LxDebuggerShell> {
  _LxSegment _segment = _LxSegment.problems;
  bool _paused = false;
  List<LayerXLogEntry>? _frozen;

  @override
  void initState() {
    super.initState();
    LayerXViewerState.markOpened();
  }

  @override
  void dispose() {
    LayerXViewerState.markClosed();
    super.dispose();
  }

  void _inspect(LayerXLogEntry log) {
    // Kept for compat: other parts of the viewer observe the selection.
    LayerXViewerState.selected.value = log;

    // Walk the CURRENT ranked problem list when the tapped entry is part of
    // it, so Prev/Next steps through what the tester is actually triaging.
    // Non-problem rows (opened from Everything/Console) get a single-entry
    // list, so both chevrons render disabled.
    final displayLogs =
        _paused ? (_frozen ?? LayerXLogStore.logs) : LayerXLogStore.logs;
    final problems = LxProblemsPane.problemsOf(displayLogs);
    final indexInProblems = problems.indexWhere((e) => e.id == log.id);
    final list = indexInProblems >= 0 ? problems : [log];
    final startIndex = indexInProblems >= 0 ? indexInProblems : 0;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LxDetailScreen(problems: list, startIndex: startIndex),
      ),
    );
  }

  void _togglePaused() {
    setState(() {
      _paused = !_paused;
      _frozen = _paused ? List<LayerXLogEntry>.from(LayerXLogStore.logs) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Self-contained dark theme so the viewer looks identical on top of any
    // host app and never inherits the host's (possibly light) Material theme.
    return Theme(
      data: LxTheme.debuggerTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: ValueListenableBuilder<List<LayerXLogEntry>>(
        valueListenable: LayerXLogStore.logsNotifier,
        builder: (context, logs, _) {
          final displayLogs = _paused ? (_frozen ?? logs) : logs;
          final openProblemCount =
              displayLogs.where(LayerXLogStore.isProblemEntry).length;

          return Scaffold(
            backgroundColor: LxTheme.bg,
            appBar: _appBar(context, openProblemCount),
            body: Column(
              children: [
                _segmentBar(),
                if (_paused) _pausedBanner(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    // Expand children to the full body size during the
                    // cross-fade so a pane never gets loose constraints
                    // mid-transition (which would collapse its rows to content
                    // width and overflow).
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.012),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<_LxSegment>(_segment),
                      child: _segment == _LxSegment.problems
                          ? LxProblemsPane(
                              logs: displayLogs, onInspect: _inspect)
                          : LxEverythingPane(
                              logs: displayLogs, onInspect: _inspect),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  /// The top-level [Problems | Everything] switch, styled like the Inspector's
  /// tab buttons: rounded, active = surfaceHigh fill + borderActive border.
  Widget _segmentBar() {
    Widget segment(String label, _LxSegment value) {
      final active = _segment == value;
      // §a11y: the visible chip is unchanged, but a transparent ≥48dp hit
      // area wraps it and it announces as a selected/unselected button.
      return LxKit.tapTarget(
        label: label,
        selected: active,
        onTap: () => setState(() => _segment = value),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? LxTheme.surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: active ? LxTheme.borderActive : Colors.transparent),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LxTheme.bodySecondary.copyWith(
                color: active ? LxTheme.textPrimary : LxTheme.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          // Flexible so the sans labels (§4.3 `label`, larger than the old
          // 10px mono) can never overflow a 320px-wide screen.
          Flexible(child: segment('Problems', _LxSegment.problems)),
          Flexible(child: segment('Everything', _LxSegment.everything)),
        ],
      ),
    );
  }

  /// A full-width amber banner shown under the segment bar (so it survives
  /// switching between Problems and Everything) whenever live capture is
  /// paused — the frozen list must never pass for a live one. `Resume` is the
  /// one-tap way back; the ⋯ menu items keep working alongside it.
  Widget _pausedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: LxTheme.accentAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LxTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline,
              size: 15, color: LxTheme.accentAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paused — new activity is hidden until you resume',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LxTheme.caption.copyWith(color: LxTheme.accentAmber),
            ),
          ),
          TextButton(
            onPressed: _togglePaused,
            style: TextButton.styleFrom(
              foregroundColor: LxTheme.accentAmber,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Resume',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, int openProblemCount) {
    final statusColor =
        openProblemCount > 0 ? LxTheme.accentRed : LxTheme.accentGreen;
    return AppBar(
      backgroundColor: LxTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: LxTheme.textSecondary, size: 20),
      automaticallyImplyLeading: false,
      leadingWidth: 72,
      leading: TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        style: TextButton.styleFrom(foregroundColor: LxTheme.accent),
        child: const Text(
          'Done',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: LxTheme.border),
      ),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: LxTheme.glowShadow(statusColor, spread: 3),
            ),
          ),
          const SizedBox(width: 10),
          // Flexible (not a bare Text) so the title can never overflow a
          // 320px-wide screen either — flex 2 vs. the count's flex 1 means
          // the count shrinks first when both compete for space.
          const Flexible(
            flex: 2,
            child: Text(
              'Debugger',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // §4.3 `titleM` — sans app-bar title (matches
              // LxTheme.appBarTheme's titleTextStyle; no shell prompt, no
              // monospace).
              style: TextStyle(
                color: LxTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '$openProblemCount problems',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LxTheme.caption,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          // A tooltip only sets the `tooltip` semantics property (not `label`),
          // so an explicit `semanticLabel` is what a reader announces and what
          // find.bySemanticsLabel resolves. Default IconButton hit area is 48².
          icon: const Icon(Icons.copy_all_outlined,
              size: 20, semanticLabel: 'Copy full report'),
          tooltip: 'Copy full report',
          onPressed: () => LxCopy.copyExport(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              size: 20, semanticLabel: 'More options'),
          tooltip: 'More options',
          color: LxTheme.surfaceHigh,
          onSelected: (v) {
            if (v == 'pause') _togglePaused();
            if (v == 'new-session') _confirmNewSession(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pause',
              child:
                  Text(_paused ? 'Resume live updates' : 'Pause live updates'),
            ),
            const PopupMenuItem(
                value: 'new-session', child: Text('Start a new session')),
          ],
        ),
      ],
    );
  }

  void _confirmNewSession(BuildContext context) {
    final count = LayerXLogStore.logs.length;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LxTheme.surfaceAlt,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start a new session?',
                  style: LxTheme.bodyPrimary
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "This clears all $count captured logs and can't be undone "
                'after the Undo snackbar disappears.',
                style: LxTheme.bodySecondary,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  LxCopy.copyExport(context);
                },
                child: const Text('Copy report first'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearWithUndo(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearWithUndo(BuildContext context) {
    final snapshot = List<LayerXLogEntry>.from(LayerXLogStore.logs);
    LayerXLogStore.clear();
    LayerXViewerState.selected.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Session cleared'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => LayerXLogStore.restore(snapshot),
        ),
      ));
  }
}

/// The pushed Details route: an immutable snapshot of the ranked problem
/// list (or a single non-problem entry) plus the tapped index, so Prev/Next
/// can walk it without depending on the shell's live, possibly-paused state.
class _LxDetailScreen extends StatefulWidget {
  final List<LayerXLogEntry> problems;
  final int startIndex;

  const _LxDetailScreen({required this.problems, required this.startIndex});

  @override
  State<_LxDetailScreen> createState() => _LxDetailScreenState();
}

class _LxDetailScreenState extends State<_LxDetailScreen> {
  late int _index = widget.startIndex;

  @override
  Widget build(BuildContext context) {
    final entry = widget.problems[_index];
    final total = widget.problems.length;

    return Theme(
      data: LxTheme.debuggerTheme,
      child: Scaffold(
      backgroundColor: LxTheme.bg,
      appBar: AppBar(
        backgroundColor: LxTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: LxTheme.textSecondary, size: 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Details',
              style: LxTheme.bodyPrimary
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (total > 1) ...[
              const SizedBox(width: 8),
              Text(
                '${_index + 1} of $total',
                style: LxTheme.caption.copyWith(color: LxTheme.textSecondary),
              ),
            ],
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: LxTheme.border),
        ),
      ),
      // Keyed per entry so Prev/Next resets the report's scroll position
      // (and any per-entry state) instead of reusing the old offset.
      body: LxInspectorPane(key: ValueKey(entry.id), log: entry),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: const BoxDecoration(
            color: LxTheme.surface,
            border: Border(top: BorderSide(color: LxTheme.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    semanticLabel: 'Previous problem'),
                tooltip: 'Previous problem',
                onPressed: _index > 0 ? () => setState(() => _index--) : null,
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => LxCopy.copy(
                      context, LayerXReportFormatter.formatIssue(entry)),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy bug report'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    semanticLabel: 'Next problem'),
                tooltip: 'Next problem',
                onPressed:
                    _index < total - 1 ? () => setState(() => _index++) : null,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
