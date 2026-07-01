# Viewer Overhaul — Phase 2 Design

**Date:** 2026-07-01
**Status:** Approved (design)
**Scope:** In-app viewer UI only. Builds on Phase 1 (the `LayerXLogCategory`
facet + source `file:line`, already shipped in 1.3.0).

## Context

The Neo Terminal viewer (`LxDebuggerShell`) has four panes: Dashboard, Network,
Console, Inspector. Already present: search, source-filter chips, colored levels,
auto-scrolling lists, "export all → clipboard", clear, and per-payload copy in
the Inspector.

Phase 1 added a `category` facet and `sourceFile`/`sourceLine` to every entry,
but the viewer does not yet surface them, and several requested controls are
missing.

## Goals (the remaining requested viewer features)

1. **Category filter** in the Console — the headline: turn the new categories
   into filterable "sections".
2. **Level filter** in the Console.
3. **Pause / resume** live logs.
4. **Collapse / expand stack traces** in the Inspector (the raw `stackTrace` is
   not shown anywhere today).
5. **Per-row copy** in the Console.
6. Surface the Phase-1 data: show **Category** and **Source `file:line`** in the
   Inspector.

## Non-goals

- **Native OS share sheet.** The existing "export all → clipboard" already
  produces the shareable text report; a true share sheet needs a plugin
  (`share_plus`) and a new dependency for every consumer. Deliberately omitted
  to keep this debug package dependency-light; can be a later opt-in.
- Search, colored levels, export, clear, per-payload copy, auto-scroll — already
  exist, untouched.

## Design

All viewer files are internal (`ignore_for_file: public_member_api_docs`); no
public API changes. Follow the existing chip/`LxKit`/`LxTheme` patterns.

### 1. Console — category filter (`lx_console_pane.dart`)

Replace the source-filter chip row with a **category** chip row. Source is a
coarse ownership hint (app/server/backend/network) that the richer category
facet subsumes, and source is still shown per-row and in the Inspector, so this
is a net upgrade rather than a loss. The row shows `All` plus **only the
categories present in the current logs** (dynamic, so it never shows 12 empty
chips), each tinted with `category.color`. State: `LayerXLogCategory? _category`.
Filtering ANDs with the existing search.

### 2. Console — level filter (`lx_console_pane.dart`)

A compact funnel `PopupMenuButton<LayerXLogLevel?>` in the filter row: `All`
plus each `LayerXLogLevel` (colored dot + label). State:
`LayerXLogLevel? _level`. ANDs with category + search. The funnel icon tints to
the accent when a level is active.

### 3. Console — per-row copy (`lx_console_pane.dart`)

Each row gets a trailing, low-emphasis copy icon. Tapping it copies a one-line
summary — `[HH:MM:SS] [LEVEL] [Category] message (file:line)` — to the clipboard
and shows a snackbar, without navigating to the Inspector (the row tap still
inspects).

### 4. Shell — pause / resume (`lx_debugger_shell.dart`)

An app-bar toggle (`Icons.pause`/`Icons.play_arrow`). State on the shell:
`bool _paused`, `List<LayerXLogEntry>? _frozen`. The shell already rebuilds via
`ValueListenableBuilder` on `LayerXLogStore.logsNotifier`; when `_paused`, it
passes the frozen snapshot to the panes instead of the live list. Pausing
captures the current list into `_frozen`; resuming clears it. New logs keep
accumulating in the store (never dropped) — only the *display* is frozen. A
small `PAUSED` pill appears in the header while paused.

### 5. Inspector — category, location, collapsible stack trace (`lx_inspector_pane.dart`)

- Add to the Overview DETAILS: **Category** (`e.category.label`) and, when
  present, **Location** (`e.sourceFile:e.sourceLine`).
- Add a **STACK TRACE** section shown when `e.stackTrace != null`: a tappable
  header row (`STACK TRACE` + a chevron that rotates) that expands/collapses a
  `SelectableText` of the trace in a bordered mono block, with a copy button.
  Collapsed by default (traces are long). Implemented as a small stateful
  section within the pane (a `_collapsed` bool), or an `ExpansionTile` styled to
  the theme.

### Shared helpers (`lx_ui_kit.dart`)

Add if useful: `LxKit.categoryChip(...)` and a `LxKit.copySummary(entry)` string
builder, to keep the panes lean.

## Testing strategy

Widget tests (VM, `flutter test`), following the existing `viewer_test.dart` /
`shell_redesign_test.dart` patterns (pump the pane/shell in a `MaterialApp`,
seed `LayerXLogStore`, tap, assert).

- **Category filter:** seed logs across categories; tapping a category chip
  shows only that category's rows; `All` restores.
- **Level filter:** selecting a level narrows rows to that level.
- **Per-row copy:** tapping the copy icon does not navigate and puts the
  summary on the clipboard (assert via `Clipboard`/`SystemChannels` mock).
- **Pause:** with the shell paused, adding a new log to the store does not add a
  row until resume.
- **Inspector:** an entry with a `category`, `sourceFile`/`sourceLine`, and
  `stackTrace` shows the category label, the location, and a collapsed stack
  section that expands on tap.
- **No overflow:** the existing 320px overflow test must stay green with the new
  filter row.

## Backward compatibility

Internal UI only; no public API, model, or store changes. All existing viewer
tests must stay green.

## Rollout

Minor bump to **1.4.0** with a CHANGELOG entry and refreshed pub.dev screenshots
(the mockups already show category chips; regenerate if the final UI differs).
