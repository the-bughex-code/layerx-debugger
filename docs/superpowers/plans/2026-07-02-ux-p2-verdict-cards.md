# UX Redesign P2 — Verdict Cards & Bug-Report Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Task-by-task, full-suite gate between tasks.

**Goal:** Put the content into the P1 shells (UX spec §9 P2, `docs/ux/2026-07-01-layerx-viewer-ux-redesign.md:1451-1474`): every Problem card leads with a plain-language verdict from `LayerXBlameEngine`; the detail reads top-to-bottom as an assignable bug report with a persistent **Copy bug report** button; states are honest (empty-vs-filtered, paused banner); jargon is swept. Ships as **1.7.0**.

**Carry-over ack (P1 final review, finding 3):** slow-only rows appeared in the inbox but in no count. P2 resolves it by moving the slow rule INTO `LayerXLogStore.isProblemEntry` so the inbox, FAB badge, header, and settings tile all agree (Task E).

**Interpretation notes (roadmap was written pre-P1):**
- Roadmap 5b ("remove the health hero from the default surface") is already satisfied structurally — the Dashboard now lives inside Everything. Task D only adds a clarifying label under the score. No removal.
- Roadmap 6's "demote raw VERBOSE/DEBUG/category chips into the Everything filter sheet" is scoped to the wording sweep only; the chips already sit one tap deep inside Everything. A structural filter sheet is NOT part of P2 (P2 acceptance doesn't require it).

**Test discipline:** as P1 (VM tests, bounded pumps, `_pumpFrames` pattern across transitions, full suite + `dart analyze lib/ test/` clean per commit, never stage `example/pubspec.lock`).

---

### Task A: Problem card = verdict-first

**Files:** Modify `lib/src/mvvm/view/shell/lx_problems_pane.dart`; extend `test/widgets/problems_pane_test.dart`.

Behavior (upgrades the minimal P1 row into the flagship card):
- Each row becomes a card (`LxKit.railCard(levelColor)` idiom or bordered container) rendering, top-to-bottom:
  1. Plain title: first line of `e.message` (2-line ellipsis; red tint for error/fatal stays).
  2. **Fault chip**: `e.source.label` (friendly, e.g. `🖥 Server Error`) as a small pill tinted `e.source.color`.
  3. **Verdict line** (the Copilot): `LayerXBlameEngine.analyze(e)?.responsibleParty` — one line, ellipsized, secondary style, prefixed with nothing (the text carries its own emoji). Absent when `analyze` returns null (info-level slow rows).
  4. Meta line: `relativeTime · ×N (when >1) · ⏱ Nms (when slow)` (keep P1 content).
- **Crash/fatal strongest treatment**: fatal-level cards use a red-tinted surface (`LxTheme.accentRed.withValues(alpha: 0.08)` background) plus the red rail — visually the loudest thing on screen.
- Verdict computation must be resilient: wrap `analyze` in a try/catch returning null (never let a card builder throw).

Required tests (extend the existing file):
1. A 500-error entry's card shows its `source.label` text AND a verdict containing 'Backend' (the blame engine's 5xx verdict).
2. An info-level slow row shows NO verdict line (analyze returns null) but keeps its `⏱` chip.
3. A fatal entry renders before an error entry (rank) — already covered; add: fatal card exists once (sanity that decoration change didn't duplicate).

Commit: `feat(viewer): verdict-first problem cards (blame engine on the inbox)`

---

### Task B: Detail reads as a bug report

**Files:** Modify `lib/src/mvvm/view/shell/lx_inspector_pane.dart`; create `test/widgets/detail_bug_report_test.dart`; update `test/widgets/inspector_phase2_test.dart` + any test asserting the old tab strip.

Behavior — replace the 4-tab strip (`Overview | Response | Request | Trace`) with ONE scroll in natural order:
1. **Summary** — existing header row (method/endpoint/status for network; icon+message otherwise) stays as-is above the scroll.
2. **WHO TO ASSIGN & WHY** — new section, only when `LayerXBlameEngine.analyze(e) != null`: `blame.responsibleParty` (title style, its color), `blame.explanation` (body), `blame.qaNote` in a bordered tip box. (This is the biggest single win of the whole redesign.)
3. **WHAT WE SUGGEST** — the existing `suggestedSolution` amber lightbulb box (keep, now after blame).
4. **DETAILS** — the existing `_kv` block with Task-4 fixes folded in: `_kv('Source', e.source.label)` (was `.name`), `_kv('Time', '${LayerXReportFormatter.relativeTime(e.timestamp)} · ${LxKit.clockTime(e.timestamp)}')` (was ISO-8601). Category/Location/Status/etc. stay.
5. **WHAT THE APP SENT (REQUEST)** — the request payload block (SelectableText mono + LxCopy button) — **before** response, fixing the reversed order.
6. **WHAT THE SERVER ANSWERED (RESPONSE)** — same treatment. Contract-changes section stays adjacent to response (wording updated in Task E later; leave strings as-is here).
7. **JOURNEY** — the existing `_trace` timeline, inline under a section label.
8. **TECHNICAL DETAILS** — the existing collapsed stack section (collapsed by default, unchanged).
Empty payloads: omit the section entirely (no more 'NO RESPONSE BODY' empty-state screens). Remove `_tab`/`_tabButton`/`_tabBody` and the `Response/Request/Trace` tab code.

Required tests (new file):
1. A 500 entry with blame → 'WHO TO ASSIGN & WHY' section shows text containing 'Backend'; request text appears ABOVE response text (compare `tester.getTopLeft` dy of the two SelectableTexts or assert string order via widget order).
2. Source shows the friendly label (finds `🖥 Server Error`-style text, NOT a bare 'server' row); no ISO-8601 'T'/'Z' timestamp string appears (assert `find.textContaining('Z)')`… simpler: assert `find.textContaining('ago')` exists in DETAILS).
3. An info entry with no stack/blame shows neither 'WHO TO ASSIGN' nor 'TECHNICAL DETAILS'.
Update `inspector_phase2_test.dart`: category/location/stack assertions remain valid (stack section unchanged) — only remove/replace its tab interactions if any.

Commit: `feat(viewer): detail restructured as a top-to-bottom bug report (blame first, request before response)`

---

### Task C: Persistent "Copy bug report" + Prev/Next

**Files:** Modify `lib/src/mvvm/view/shell/lx_debugger_shell.dart` (the pushed Details route); create `test/widgets/detail_copy_nav_test.dart`.

Behavior:
- The Details `Scaffold` gains a `bottomNavigationBar`: a safe-area bar with **[‹ Prev] [Copy bug report] [Next ›]**. Copy = `FilledButton.icon` (accent, full-flex center) calling `LxCopy.copy(context, LayerXReportFormatter.formatIssue(entry))`. Prev/Next = `IconButton(Icons.chevron_left/right)`.
- Prev/Next walk the CURRENT problem list: compute `LxProblemsPane.problemsOf(displayLogs)` at push time (pass the ranked list + start index into the detail screen widget; make the detail a small private `StatefulWidget` in the shell file holding `_index`, rendering `LxInspectorPane(log: problems[_index])`). Buttons disabled (greyed) at the ends. Non-problem rows (opened from Everything/Console) push with a single-entry list (chevrons disabled).
- App-bar title stays 'Details'; add `'${index+1} of ${problems.length}'` as a subtitle-style suffix when list length > 1.

Required tests:
1. Open a problem from the inbox (2 problems seeded) → 'Copy bug report' visible; tapping it shows the LxCopy confirmation snackbar.
2. Tapping Next shows the second problem's message + '2 of 2'; Prev returns; Prev at index 0 is disabled (IconButton's `onPressed == null`).

Commit: `feat(viewer): persistent Copy-bug-report button with Prev/Next problem walking`

---

### Task D: Honest states — filtered-empty vs truly-empty + paused banner

**Files:** Modify `lib/src/mvvm/view/shell/lx_console_pane.dart`, `lx_network_pane.dart`, `lx_problems_pane.dart`, `lx_debugger_shell.dart`, `lx_dashboard_pane.dart` (label under score); create `test/widgets/honest_states_test.dart`.

Behavior:
1. **Filtered-empty ≠ truly-empty.** Console + Network: when the raw `logs` list is non-empty but the filtered rows are empty, show a distinct state: `LxKit.emptyState(Icons.filter_alt_off, 'NOTHING MATCHES', 'Showing 0 of N — clear the filters to see everything.')` PLUS a visible `TextButton('Clear filters')` that resets that pane's local filter state (query, category/level for console; query/chip for network). Truly-empty keeps the existing wording. Problems pane truly-empty copy becomes the scope-honest line: `'Go use the app — anything that breaks shows up here. This records what happened; it can\'t retry for you.'`
2. **Sticky partial-results header.** Console + Network: when filters hide ≥1 row but some remain, a slim header row above the list: `'Showing N of M'` + `TextButton('Show all')` (same reset). Implement once as `LxKit.filterSummaryBar(shown, total, onClear)` in `lx_ui_kit.dart`.
3. **Paused banner.** In the shell, when `_paused`, render a full-width banner directly under the segment bar (both segments): amber-tinted container, `Icons.pause_circle_outline`, text `'Paused — not capturing new problems'`, trailing `TextButton('Resume')` that unpauses. Keep the ⋯ menu items.
4. **Score label.** Dashboard health hero: add a one-line caption under the score: `'Developer metric — problems above are what matter'` (secondary style).

Required tests:
1. Console with 3 info logs + a search query matching none → 'NOTHING MATCHES' + 'Clear filters'; tapping it restores the rows.
2. Console with a category filter hiding 1 of 3 → 'Showing 2 of 3' + 'Show all' restores.
3. Shell paused via ⋯ → banner text visible on Problems AND on Everything; tapping the banner's 'Resume' hides it and live logs flow again.

Commit: `feat(viewer): honest empty/filtered/paused states with one-tap recovery`

---

### Task E: Vocabulary sweep + slow rule into the count

**Files:** Modify `lib/src/repository/layerx_log_store.dart` (slow rule), `lib/src/mvvm/view/shell/lx_problems_pane.dart` (simplify `problemsOf`), `lx_inspector_pane.dart` + `lx_network_pane.dart` (wording), `lib/src/repository/layerx_report_formatter.dart` (wording already friendly — verify only); extend `test/logging/open_problem_count_test.dart` + a small wording test.

Behavior:
1. **Slow rule into the store:** `isProblemEntry` gains `|| _isSlow(log)` where `_isSlow` reads `extras['duration_ms'] is int && >= slowRequestThresholdMs` (new `static int slowRequestThresholdMs = 800;`, doc-commented public). `LxProblemsPane.problemsOf` drops its local slow-union (keeps ranking; slow tier ranks by `isSlow && !level-problem && !changed`). Result: inbox, badge, header, settings all agree (closes P1 review finding 3).
2. **Wording sweep** (user-facing strings only):
   - Inspector 'CONTRACT CHANGES' → 'RESPONSE CHANGED SHAPE'; keep the +/−/~ rows.
   - Network pane: the 'Δ CHANGED' chip label → 'CHANGED'; any row 'Δ' marker gets tooltip-free plain treatment (keep the amber rail).
   - Problems/inspector: no other Δ/schema strings remain user-visible (grep `Δ|schema|SCHEMA|contract|CONTRACT` across `lib/src/mvvm/view/` and fix what's user-facing; `schemaChanges` API names stay).
3. Verify `formatIssue`'s changed-shape section already says "The API response changed since the previous call" (it does — no change).

Required tests:
1. `open_problem_count_test.dart`: a success entry with `duration_ms: 900` counts as a problem; `849→` non-problem at 800 threshold boundary (`800` counts, `799` doesn't).
2. Widget: network pane chip row shows 'CHANGED' and not 'Δ CHANGED'; inspector with schemaChanges shows 'RESPONSE CHANGED SHAPE'.
3. Existing problems-pane rank test stays green (slow tier still last).

Commit: `feat(viewer): plain-language sweep + slow requests count as problems everywhere`

---

### Task F: Release 1.7.0

- `pubspec.yaml` → `1.7.0`; CHANGELOG (above `## 1.6.0`):

```markdown
## 1.7.0

### Changed

- **UX P2: the debugger now tells you whose fault it is.** Every problem card
  leads with a plain-language verdict from the built-in blame engine (e.g.
  "🖥️ Backend Server (5xx Internal Error)"), and opening a problem reads
  top-to-bottom like a bug report: who to assign & why → suggested fix →
  details → what the app sent → what the server answered → journey → collapsed
  technical stack. A persistent **Copy bug report** button (with Prev/Next to
  walk problems) produces a complete, paste-ready ticket. States are honest:
  filtered-empty offers "Clear filters", truly-empty explains the tool records
  (it can't retry), and pausing shows a full-width banner. Friendly labels
  everywhere (🖥 Server Error instead of `server`, relative time instead of
  ISO-8601, "response changed shape" instead of Δ/schema). Slow requests
  (≥800ms, configurable via `LayerXLogStore.slowRequestThresholdMs`) now count
  as problems in every badge and count.
```

- Full verify + dry-run (0 warnings) → commit `chore(viewer): release 1.7.0 — verdict cards & bug-report detail (UX P2)` → publish → merge `feat/ux-p2` → `dev-umair` → push.

---

## Self-Review
- Roadmap P2 map: 1→A, 2→B, 3→C, 4→B(4), 5→D (5b reinterpreted post-P1, labeled), 6→E (sheet descoped, wording done). P1-review carry-over →E(1). All P2 acceptance criteria testable: verdict on card (A1), request-before-response + top-to-bottom report + copy button (B1/C1), friendly source/time (B2), filtered-vs-empty distinct + recovery (D1/D2), paused banner (D3), no score on default surface (structural since P1).
- Selectors/behaviors specified; layout delegated to implementers matching the existing idiom.
