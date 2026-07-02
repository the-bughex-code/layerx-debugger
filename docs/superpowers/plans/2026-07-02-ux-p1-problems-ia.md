# UX Redesign P1 — Problems/Everything IA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Execute task-by-task with a full-suite gate between tasks.

**Goal:** Ship the P1 structural pivot (UX spec §9 P1, `docs/ux/2026-07-01-layerx-viewer-ux-redesign.md:1428-1447`): the 4-tab shell becomes a two-segment **[Problems | Everything]** IA; the Inspector becomes a pushed detail route (never a cold tab); a labeled **Done** close; all counts unify on `LayerXLogStore.openProblemCount`. Ships as **1.6.0**.

**Constraints:** internal viewer only — no public API changes beyond what P0 added. `LxBottomNav` stays in the codebase (reusable inside Everything) but is no longer the top-level switcher. Existing pane-level filters stay inside their panes (they are now demoted one tap behind Everything, which satisfies P1; the filter-sheet consolidation belongs to P2 task 6). Follow existing `LxTheme`/`LxKit` idioms. Design intent lives in the UX doc §2 (IA) — implementers should skim `docs/ux/2026-07-01-layerx-viewer-ux-redesign.md` §2 before building.

**Test discipline:** TDD per task; `flutter test <path>` (VM; if "Failed to find … flutter_tester" run `flutter precache --force --universal` once). Full suite + `dart analyze lib/ test/` clean before each commit. Shell tests must use bounded pumps (blinking cursor never settles) and small repeated pump steps across route transitions (see `test/widgets/new_session_flow_test.dart` `_pumpFrames` pattern). Never stage `example/pubspec.lock`.

---

### Task A: `LxProblemsPane` — the ranked problem inbox (list shell)

**Files:** Create `lib/src/mvvm/view/shell/lx_problems_pane.dart`; Test `test/widgets/problems_pane_test.dart`.

Behavior (card CONTENT is deliberately minimal — P2 upgrades it):
- Input: `{required List<LayerXLogEntry> logs, required ValueChanged<LayerXLogEntry> onInspect}` (same contract as sibling panes).
- Membership: `LayerXLogStore.isProblemEntry(e)` **plus a slow-request rule**: any entry with `LxKit.durationOf(e) != null && >= 800` (ms) is also a problem row even at success level. Expose the union as a static, testable function: `static List<LayerXLogEntry> problemsOf(List<LayerXLogEntry> logs)`.
- Ranking (worst first): fatal & error → warning → responseChanged-only → slow-only; ties broken by newest timestamp first. Expose as part of `problemsOf` (sorted output).
- Row (minimal for P1): level-colored rail + level icon (reuse `LxKit.levelIcon`), first line of message (2-line ellipsis), meta line `relativeTime · source.label` (use `LayerXReportFormatter.relativeTime` + `e.source.label`), `×N` occurrence chip when >1, slow rows show `⏱ {duration}ms`. Tap → `onInspect(e)`.
- Empty state: `LxKit.emptyState(Icons.inbox_outlined, 'NO PROBLEMS YET', 'Go use the app — anything that breaks will show up here.')`.

Required tests (write first, watch fail):
1. `problemsOf` unit: seed info+error+warning+slow(900ms success)+fast(100ms success)+responseChanged — returns exactly [error, warning, changed, slow] in rank order (construct timestamps so ties are exercised: two errors, newer first).
2. Widget: pump with one error + one info → shows the error message, does NOT show the info message; tapping the row fires `onInspect` with that entry.
3. Widget: slow success row shows `⏱ 900ms`.

Commit: `feat(viewer): LxProblemsPane — ranked problem inbox with slow-request rule`

---

### Task B: `LxEverythingPane` — demoted developer surface

**Files:** Create `lib/src/mvvm/view/shell/lx_everything_pane.dart`; Test `test/widgets/everything_pane_test.dart`.

Behavior:
- Input: `{required List<LayerXLogEntry> logs, required ValueChanged<LayerXLogEntry> onInspect}`.
- Hosts the existing three panes behind a small sub-switch (chips or an `LxBottomNav` reused as an inner bar — implementer's choice, match theme): **Console | Network | Dashboard** (Console default, it's the closest to "all logs"). Construct the sub-panes exactly as the shell does today: `LxConsolePane(logs:, onInspect:)`, `LxNetworkPane(logs:, onInspect:)`, `LxDashboardPane(logs:, onInspect:)`.
- Keep each pane's own filters/search untouched.

Required tests:
1. Default shows the Console pane's search field (hint 'search logs…').
2. Switching to Network shows the network search hint ('search endpoint or method…'); switching to Dashboard with an error log present shows 'RECENT ISSUES'.

Commit: `feat(viewer): LxEverythingPane — Console/Network/Dashboard demoted behind one switch`

---

### Task C: Shell pivot — segmented [Problems | Everything], detail-only Inspector, Done

**Files:** Modify `lib/src/mvvm/view/shell/lx_debugger_shell.dart`; create `test/widgets/shell_p1_ia_test.dart`; UPDATE existing shell-coupled tests to the new IA (`test/widgets/viewer_test.dart` console-tab case, `test/widgets/shell_redesign_test.dart`, `test/widgets/shell_pause_test.dart`, `test/widgets/new_session_flow_test.dart` if selectors moved).

Behavior:
- Replace the `LxBottomNav` top-level switcher + `_index`/panes array with TWO segments: a top segmented control **[Problems | Everything]** directly under the app bar (styled like the tab buttons in `LxInspectorPane._tabButton`: rounded, active = `surfaceHigh` + `borderActive`). Problems is the landing segment. Bodies: `LxProblemsPane` / `LxEverythingPane` fed `displayLogs` (pause snapshot logic unchanged).
- **Inspector becomes a pushed route.** `_inspect(log)` now does `Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: LxTheme.bg, appBar: <simple bar: back arrow + 'Details'>, body: LxInspectorPane(log: log))))`. Remove the Inspector tab/pane and the `LayerXViewerState.selected` ValueListenableBuilder wiring from the shell (keep `LayerXViewerState.selected.value = log;` set before pushing, for compat). The `NOTHING SELECTED` empty state stays in `LxInspectorPane` but is now unreachable from the shell.
- **Done button:** `leading` of the app bar becomes a labeled `TextButton('Done')` that pops the shell (`Navigator.of(context).maybePop()`). Keep `automaticallyImplyLeading: false`; set `leadingWidth` ~72 so the label fits.
- **Overflow consolidation:** move Pause/Resume out of the icon row into the existing `⋯` `PopupMenuButton` as labeled items: 'Pause live updates' / 'Resume live updates' (same `_paused/_frozen` logic), alongside 'Start a new session'. Keep the export-all copy icon as-is.
- Header prompt: change the count segment to problems: `'$openProblemCount problems'` (replacing `'$total logs'`; full de-terminalization is P3). Status dot: red when `openProblemCount > 0`.

Required tests (new `shell_p1_ia_test.dart`):
1. Opening the shell lands on Problems: with one error seeded, its message is visible without any tab tap; the strings 'Dashboard'/'Inspector' nav labels are absent.
2. Tapping 'Everything' shows the Console search field; tapping 'Problems' returns.
3. Tapping a problem row pushes a detail screen showing 'Details' and the entry's message; back arrow returns to the list.
4. 'Done' is visible; tapping it pops the shell (pump the shell via `Navigator.push` from a host so the pop is observable).
5. Pause via overflow: open ⋯ → 'Pause live updates' → add a log → not shown; ⋯ → 'Resume live updates' → shown (adapt `shell_pause_test.dart` to this flow and delete its icon-based taps, or fold it into this file and delete the old one — implementer's choice, state what you did).

Update the existing tests to the new IA rather than deleting assertions: `viewer_test.dart`'s "renders a captured message in the console" now goes Problems→Everything (or asserts the message on Problems since an info log isn't a problem — go via Everything); `shell_redesign_test.dart`'s 4-destination overflow walk becomes: Problems, Everything(Console/Network/Dashboard sub-switch), and a pushed detail — keep the 320px no-overflow assertion for each surface.

Commit: `feat(viewer): two-segment Problems/Everything shell, detail-only Inspector, labeled Done`

---

### Task D: Unify every count on `openProblemCount`

**Files:** Modify `lib/src/widgets/lx_fab_trigger.dart` (badge), `lib/src/widgets/parts/lx_debug_settings_button.dart` (subtitle); Test `test/widgets/unified_count_test.dart`.

Behavior:
- FAB badge: `badgeCount = LayerXLogStore.openProblemCount` (replace the errorCount/totalCount switching at ~`:122-125`). Keep `hasErrors` (errorCount>0) ONLY for the red-vs-green accent/icon swap. Badge hidden when 0 (existing `if (badgeCount > 0)` stays).
- Settings tile subtitle: `'$problemCount problems'` via `LayerXLogStore.openProblemCount` (replace `'$totalCount logs • $errorCount errors'`); title/icon unchanged.
- Existing `viewer_test.dart` FAB-badge test asserts `find.text('1')` after one error — still passes (1 error = 1 problem). If any test asserted total-count badges, update it.

Required tests:
1. Seed 2 errors + 3 infos + 1 warning → FAB badge text '3'; settings subtitle contains '3 problems'.
2. Seed 3 infos only → FAB shows NO badge (findsNothing for badge text), subtitle contains '0 problems'.

Commit: `feat(viewer): FAB badge and settings tile read openProblemCount`

---

### Task E: Release 1.6.0

- `pubspec.yaml` → `1.6.0`; CHANGELOG entry (above `## 1.5.0`):

```markdown
## 1.6.0

### Changed

- **UX P1: the viewer now opens on a Problems inbox.** The 4-tab shell is
  replaced by two segments — **Problems** (a worst-first inbox of errors,
  crashes, warnings, changed responses, and slow requests ≥800ms) and
  **Everything** (the full Console / Network / Dashboard, one tap away).
  Details open by tapping a row (the Inspector can no longer cold-open on
  "NOTHING SELECTED"), a labeled **Done** closes the viewer, Pause/Resume moved
  into the ⋯ menu as labeled actions, and the FAB badge / header / settings
  tile now all show the same number: open problems.
```

- Full verify: `flutter test test/ && dart analyze lib/ test/ bin/ && rm -rf example/build && flutter pub publish --dry-run` (0 warnings).
- Commit `chore(viewer): release 1.6.0 — Problems/Everything IA (UX P1)`, publish `--force`, merge → `dev-umair`, push.

---

## Self-Review
- Roadmap P1 task map: 1→C (segmented shell), 2→A (problems pane + slow rule), 3→B (Everything), 4→C (detail-only Inspector), 5→C (Done + overflow), 6→D (unified counts). Filter-sheet consolidation explicitly deferred to P2 task 6 (P1 acceptance doesn't require it). All P1 acceptance criteria covered by tests: land-on-Problems (C1), drill-in-only Inspector (C3), slow-call-as-problem (A1/A3), always-visible Done (C4), identical counts (D1/D2).
- No placeholders; behavior + selectors specified. Layout code delegated to implementers following existing pane idioms (they read the sibling panes + UX doc §2).
