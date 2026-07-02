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
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: LxTheme.bg,
          appBar: AppBar(
            backgroundColor: LxTheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme:
                const IconThemeData(color: LxTheme.textSecondary, size: 20),
            title: Text(
              'Details',
              style: LxTheme.bodyPrimary
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: LxTheme.border),
            ),
          ),
          body: LxInspectorPane(log: log),
        ),
      ),
    );
  }

  void _togglePaused() {
    setState(() {
      _paused = !_paused;
      _frozen =
          _paused ? List<LayerXLogEntry>.from(LayerXLogStore.logs) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
    );
  }

  /// The top-level [Problems | Everything] switch, styled like the Inspector's
  /// tab buttons: rounded, active = surfaceHigh fill + borderActive border.
  Widget _segmentBar() {
    Widget segment(String label, _LxSegment value) {
      final active = _segment == value;
      return GestureDetector(
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
            style: LxTheme.monoSm.copyWith(
                color: active ? LxTheme.textPrimary : LxTheme.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          segment('Problems', _LxSegment.problems),
          segment('Everything', _LxSegment.everything),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, int openProblemCount) {
    final statusColor =
        openProblemCount > 0 ? LxTheme.accentRed : LxTheme.accentGreen;
    final path =
        _segment == _LxSegment.problems ? 'problems' : 'everything';
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
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5, height: 1.2),
                children: [
                  const TextSpan(
                      text: 'layerx',
                      style: TextStyle(
                          color: LxTheme.accent, fontWeight: FontWeight.w700)),
                  const TextSpan(
                      text: '@dbg ',
                      style: TextStyle(color: LxTheme.textSecondary)),
                  TextSpan(
                      text: '~/$path ',
                      style: const TextStyle(color: LxTheme.accentCyan)),
                  const TextSpan(
                      text: r'$ ',
                      style: TextStyle(color: LxTheme.textSecondary)),
                  TextSpan(
                      text: '$openProblemCount',
                      style: const TextStyle(
                          color: LxTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const TextSpan(
                      text: ' problems',
                      style: TextStyle(color: LxTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const _LxBlinkingCursor(),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_all_outlined, size: 20),
          tooltip: 'Export all',
          onPressed: () => LxCopy.copyExport(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          color: LxTheme.surfaceHigh,
          onSelected: (v) {
            if (v == 'pause') _togglePaused();
            if (v == 'new-session') _confirmNewSession(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pause',
              child: Text(
                  _paused ? 'Resume live updates' : 'Pause live updates'),
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

/// A small blinking block cursor that gives the header its live-terminal feel.
class _LxBlinkingCursor extends StatefulWidget {
  const _LxBlinkingCursor();

  @override
  State<_LxBlinkingCursor> createState() => _LxBlinkingCursorState();
}

class _LxBlinkingCursorState extends State<_LxBlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(_BlinkTween()),
      child: Container(
        width: 7,
        height: 15,
        decoration: BoxDecoration(
          color: LxTheme.accent,
          borderRadius: BorderRadius.circular(1),
          boxShadow: LxTheme.glowShadow(LxTheme.accent, spread: 3),
        ),
      ),
    );
  }
}

/// Square-wave opacity: solid for the first half of the cycle, hidden for the
/// second — a classic terminal cursor blink rather than a smooth fade.
class _BlinkTween extends Animatable<double> {
  @override
  double transform(double t) => t < 0.5 ? 1.0 : 0.0;
}
