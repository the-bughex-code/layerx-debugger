# UX Redesign P4 — Accessibility Floor & Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Task-by-task, full-suite gate between tasks.

**Goal:** Ship the final phase (UX spec §9 P4, `docs/ux/2026-07-01-layerx-viewer-ux-redesign.md:1498-1519`): ≥48dp touch targets, screen-reader semantics on every control, reduce-motion support with a one-shot new-problem pulse, a first-run coach mark, on-screen scope honesty, and a dynamic-type/RTL smoke pass. Ships as **1.9.0** — completing the 1.5.0→1.9.0 redesign arc.

**Persistence note (per spec):** the coach-mark "seen" flag is in-memory for this release (static bool, reset on restart) — true persistence is the future 2.1.0. State this in the coach-mark doc comment.

**Test discipline:** as prior phases (VM, bounded pumps, full suite + `dart analyze lib/ test/` clean per commit, never stage `example/pubspec.lock`).

---

### Task A0: Finish the AA sweep — semantic colors for blame/source/level/category + the real pill gate

**Carry-over from the P3 final review (findings 2-4), scoped here because P4 is the accessibility phase.**

**Files:** Modify `lib/src/mvvm/view_model/layerx_blame_engine.dart` (all `color:` values), `lib/src/config/enums/layerx_log_source.dart`, `layerx_log_level.dart`, `layerx_log_category.dart` (color getters); extend `test/config/theme_contrast_test.dart`; update any test asserting old enum colors (e.g. `models_test.dart`) with justification.

Behavior:
1. **Extend the contrast gate FIRST (TDD)** with the patterns actually rendered:
   - Every `LayerXLogSource.color` as text on its own 14%-alpha tint over `surface` ≥ 4.5 (the `LxKit.pill` pattern).
   - Every `LayerXLogLevel.color` on `surface` ≥ 3.0 (rails/icons, decorative) AND error/fatal ≥ 4.5 (used as title text).
   - Every `LayerXLogCategory.color` as chip text on its 14% tint ≥ 4.5.
   - Every `LayerXBlameEngine` verdict color — enumerate via representative entries through `analyze()` (5xx, 503, network, timeout, 429, 401, 403, 409, 422, 404, parse, flutter, platform, fallback) — on `surface` ≥ 3.0 (icon use; text now uses tokens after the P3 hotfix).
   - `methodColor(DELETE)`-as-text on its tint ≥ 4.5 (the reviewer measured 4.31 — the remap below must clear it, e.g. DELETE text renders `criticalOn` on the critical tint, giving `criticalOn` its first real call sites).
   Watch these fail against today's values.
2. **Remap to the §4.2 semantic set until the gate passes** (bright-on-dark variants, hard-coded hexes are fine in enums as today): fatal → `#FF3B3B`-family with fatal TEXT/title usage ≥4.5 (pair with `criticalOn #FFB4B4` where text-on-tint), error → `#FF6B6B`, warning → `#F4B740`, source colors → bright semantic hues (app → a bright info/violet that clears 4.5-on-tint, server → `#FF6B6B`, backend → `#F4B740`, network → `#5AA9FF`, unknown → `#AEB8C4`), category colors likewise, blame colors → the same semantic families (5xx/critical → danger family, network → info, timeouts/rate-limit → warning, app bugs → a bright violet, fallback → neutral).
3. **Crash band gets its call sites:** fatal rails/icons/chips now use the new bright fatal color automatically via the enum getters; where fatal text sits on a fatal tint (problems-pane fatal card), verify ≥4.5 with the new values (adjust the tint alpha if needed).
4. `lx_bottom_nav.dart` is dead legacy (unreferenced) — DELETE the file and its tests if any reference it (grep first; report).

Required: extended gate green; full suite green (update `models_test.dart` color assertions to the new values with a "visual redesign" note); grep report for bottom-nav deletion.

Commit: `feat(viewer): AA semantic colors for blame/source/level/category; real pill-pattern contrast gate`

---

### Task A: Touch targets ≥48dp + screen-reader semantics

**Files:** Modify `lib/src/widgets/lx_fab_trigger.dart`, `lib/src/widgets/lx_edge_trigger.dart`, `lib/src/mvvm/view/shell/lx_debugger_shell.dart`, `lx_console_pane.dart`, `lx_network_pane.dart`, `lx_problems_pane.dart`, `lx_inspector_pane.dart`, `lx_ui_kit.dart`; create `test/widgets/a11y_semantics_test.dart`.

Behavior:
1. **Semantics** (there is not a single `Semantics` widget today): wrap/annotate every icon-only or gesture-only control with a meaningful label —
   - FAB root `GestureDetector` → `Semantics(button: true, label: 'Report a bug — open the debugger')` (the visible text label exists but the gesture wrapper needs button semantics; verify with the finder).
   - Edge handle → `Semantics(button: true, label: 'Open the debugger')`.
   - Shell: Done (`TextButton` has text — fine), export-all `IconButton` → `tooltip` already? ensure `tooltip: 'Copy full report'` (tooltip doubles as semantics), ⋯ menu (`tooltip: 'More options'`), segments (`Semantics(selected: active, button: true)`).
   - Console/problems rows: row `InkWell` → `Semantics(button: true, label: '<first line of message>')` comes free from the Text; the per-row copy `GestureDetector` → `Semantics(button: true, label: 'Copy this log')`.
   - Inspector: payload copy buttons (`tooltip`/label 'Copy request' / 'Copy response'), TECHNICAL DETAILS header (`Semantics(button: true, expanded: _stackOpen)` if trivially expressible — else button+label), stack copy.
   - Detail bottom bar: Prev/Next `IconButton`s → `tooltip: 'Previous problem'` / `'Next problem'` (Copy button has text).
   - Level funnel `PopupMenuButton` already has `tooltip: 'Filter by level'` (verify).
2. **Targets:** every tappable above gets a minimum 48×48 hit area — use `IconButton` defaults where possible; for bare `GestureDetector`s (row copy, stack copy, chips) add padding/`SizedBox` or `behavior: HitTestBehavior.opaque` + constraints so `tester.getSize` ≥ 48 on the tap surface (visual glyph can stay small; the padded hit area counts). Chips (category/segment/sub-switch): raise vertical hit size via padding within the existing visual look (a transparent hit-area wrapper is fine; visible chip look must not balloon).

Required tests (`a11y_semantics_test.dart`):
1. `find.bySemanticsLabel` (or SemanticsTester) locates: 'Report a bug — open the debugger' (pump overlay+FAB), 'Copy this log' (console row), 'Previous problem'/'Next problem' (pushed detail), 'Copy full report' (shell).
2. Size assertions: console per-row copy tap target ≥48×48; detail Prev/Next ≥48; FAB pill height ≥48 (it is 48).
3. Existing suites stay green (row-copy test still taps the icon; ensure the padded wrapper doesn't break `find.byIcon(Icons.copy)` uniqueness — scope finders if needed).

Commit: `feat(viewer): 48dp touch targets and screen-reader semantics on every control`

---

### Task B: Reduce-motion + one-shot new-problem pulse

**Files:** Modify `lib/src/widgets/lx_fab_trigger.dart`, `lib/src/mvvm/view/shell/lx_ui_kit.dart` (`stagger`); create `test/widgets/reduce_motion_test.dart`.

Behavior:
1. **Perpetual pulse dies.** The FAB's always-repeating pulse ring becomes event-driven: pulse (2-3 cycles, then stop) ONLY when `openProblemCount` increases while the viewer is closed (listen to the existing `logsNotifier` builder — compare against a static `_lastSeenProblemCount`, updated on pulse-trigger and when the viewer opens). At rest: no animation.
2. **Reduce-motion gate:** when `MediaQuery.maybeDisableAnimations == true` (read via `MediaQuery.maybeOf(context)?.disableAnimations ?? false`):
   - No pulse at all (new-problem signal = the badge count change alone).
   - `LxKit.stagger` returns the child directly (no tween) — thread the flag via `MediaQuery` lookup inside `stagger`'s builder (it has no context today — change signature to `stagger(BuildContext context, int index, Widget child)` and update the three call sites, or read `disableAnimations` via a `Builder`; pick the cleaner and state it).
   - The FAB mount elastic + shell AnimatedSwitcher may remain (short, non-repeating) — spec targets *perpetual* motion; document the choice.
3. Dispose safety: pulse controller no longer `..repeat()` on init; guard `forward/repeat` calls on `mounted`.

Required tests:
1. With `MediaQuery(data: MediaQueryData(disableAnimations: true))` host: pump overlay+FAB, add an error log, pump frames → no widget with a repeating animation is required — assert via absence of the pulse ring (give the ring a `Key('lx-fab-pulse')` and `findsNothing`).
2. Without reduce-motion: seed a new error while FAB rests → the pulse ring appears (findsOneWidget) then stops after its cycles (pump past duration → findsNothing).
3. Stagger: with disableAnimations, a problems list renders rows at full opacity on first frame (assert first row's Opacity == 1.0 immediately or the absence of the tween wrapper via key).

Commit: `feat(viewer): reduce-motion support; FAB pulses only on new problems`

---

### Task C: First-run coach mark + scope honesty + dynamic-type/RTL smoke

**Files:** Modify `lib/src/widgets/lx_overlay_installer.dart` or `lx_fab_trigger.dart` (coach mark host), `lx_console_pane.dart`/`lx_network_pane.dart` (empty-state scope line), `test/widgets/shell_redesign_test.dart` (scale/RTL walk); create `test/widgets/coach_mark_test.dart`.

Behavior:
1. **Coach mark:** the first time the FAB mounts in a session (`static bool _coachShown = false` — in-memory per spec), show a small dismissible bubble anchored near the FAB: `'Found a bug? Tap here.'` + a close ×. Auto-dismiss after ~6s or on any tap (tapping the bubble opens the debugger too). Never shows again in the session (`_coachShown = true` on show); never in release-off states (only when the trigger layer itself is shown). Style: surface card, visible border, caption text — matches the P3 system. Add a `reset()` hook for tests (and call from `LayerXOverlayInstaller.reset` or `resetForTesting` if trivial).
2. **Scope honesty:** the Console and Network truly-empty states add the one-liner already used on Problems-empty: append `'This records what happened — redo the action in the app.'` as the subtitle's second sentence (keep the existing first sentence).
3. **Dynamic-type/RTL smoke:** extend the 320px overflow walk (or add a sibling test in `shell_redesign_test.dart`) that runs the same Problems→Everything→detail walk under `MediaQuery(textScaler: TextScaler.linear(1.5))` and separately under `Directionality(textDirection: TextDirection.rtl)` — assert no overflow exceptions (`tester.takeException()` pattern already used there). Fix any clipping these surface (likely candidates: fixed-height chip rows, the FAB pill at 1.5×— its label may need `maxLines: 1` + ellipsis, the detail bottom bar). Report what needed fixing.

Required tests: coach mark shows once (pump overlay+FAB fresh → bubble text found; dismiss; re-insert FAB → not found), tapping it opens the shell; empty-state wording assertions; the 1.5× and RTL walks green.

Commit: `feat(viewer): first-run coach mark, scope-honest empty states, dynamic-type/RTL hardening`

---

### Task D: Release 1.9.0

- `pubspec.yaml` → `1.9.0`; CHANGELOG (above `## 1.8.0`):

```markdown
## 1.9.0

### Changed

- **UX P4: accessible to every tester.** Every control now has a ≥48dp touch
  target and a screen-reader label (VoiceOver/TalkBack never announce a bare
  "button"). With OS reduce-motion on, nothing animates perpetually — and even
  without it, the floating button's pulse now fires only when a new problem
  arrives, then rests. A one-time coach mark introduces the "Report a bug"
  button on first run, empty states say plainly that the tool records what
  happened (redo the action in the app — there is no retry button to hunt for),
  and the viewer holds up under 1.5× system text scaling and RTL locales.
  This completes the 1.5.0 → 1.9.0 usability-first redesign arc.
```

- Full verify + dry-run (0 warnings) → commit `chore(viewer): release 1.9.0 — a11y floor, reduce-motion & onboarding (UX P4)` → publish → merge → push.

---

## Self-Review
- Roadmap P4 map: 1→A (targets), 2→A (semantics), 3→B (reduce-motion + one-shot pulse), 4→C (coach mark, in-memory per the spec's persistence note), 5→C (scope line; Problems already carries it from P2), 6→C (1.5×/RTL walk). Acceptance coverage: labels+targets (A tests), no perpetual animation under reduce-motion (B tests), coach mark exactly once (C test), scope honesty in plain language (C wording tests), no clipping at 1.5×/RTL (C walks).
- In-memory flags documented as session-scoped per the spec's persistence note.
