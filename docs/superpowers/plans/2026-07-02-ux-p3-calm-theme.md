# UX Redesign P3 — Calm High-Contrast Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Task-by-task, full-suite gate between tasks.

**Goal:** Retheme the viewer per UX spec §9 P3 (`docs/ux/2026-07-01-layerx-viewer-ux-redesign.md:1477-1494`) and the design system in **§4 (lines 737-1030: §4.2 color, §4.3 typography, §4.5 components, §4.6 token migration map)**: WCAG-AA contrast on every load-bearing text token, crashes loudest, no terminal cosplay (prompt/cursor gone), monospace only where it earns it, components with visible edges, a labeled FAB. Ships as **1.8.0**.

**Blast-radius note:** every widget reads `LxTheme`/`LxKit`, so most of this lands by editing tokens once. Structure/content must NOT change — P3 is visual. All 200 existing tests must stay green except those asserting removed cosmetics (prompt/cursor) or old exact colors.

**Design authority:** implementers follow §4's concrete values (adapting to existing `LxTheme` token names via the §4.6 migration map). Where §4 offers light-vs-dark options, keep the **dark neutral** identity (this is a debug overlay inside someone else's app — a sudden white sheet is hostile); §4's dark-surface variants apply.

**Test discipline:** as prior phases (VM, bounded pumps, full suite + `dart analyze lib/ test/` clean per commit, never stage `example/pubspec.lock`).

---

### Task A: Palette + typography tokens (WCAG-AA) with a contrast gate

**Files:** Modify `lib/src/config/lx_theme.dart`; create `test/config/theme_contrast_test.dart`.

Behavior:
- Read §4.2/§4.3/§4.6 of the UX doc. Replace the low-contrast tokens: `textDim` (#38573F, ~2.4:1 — used for real content: timestamps, meta) and any text token that lands under 4.5:1 on the surfaces it's used against (`bg`, `surface`, `surfaceAlt`, `surfaceHigh`). Neutral-dark surface set per §4 (drop the green-tinted blacks for neutral ones if §4 says so), calmer accent usage; `accentRed`/fatal treatment becomes the highest-contrast, most prominent color in the system.
- Typography: `mono`/`monoSm` stay monospace ONLY for code-ish content; introduce/repurpose sans tokens for labels/meta/captions per §4.3 (e.g. `sectionLabel` and meta text become sans). Keep the public token NAMES stable where possible (widgets reference them everywhere) — change their VALUES; add new tokens only where §4 demands a distinction the current set can't express (record any renames and update usages).
- **Contrast gate test:** a pure unit test computing WCAG relative-luminance contrast for the load-bearing pairs — (textPrimary, bg), (textPrimary, surface), (textSecondary, surface), (textDim-or-successor, surface), (accentRed, surface), (accent, bg) — each asserted ≥ 4.5 (accent-on-bg for text usage; if an accent is decorative-only, assert ≥ 3.0 and say so in a comment). Implement the contrast function in the test file.

Required tests: the contrast gate (all pairs pass); full suite green (fix any test asserting old exact colors — report which).

Commit: `feat(viewer): WCAG-AA neutral palette + sans-first typography tokens`

---

### Task B: De-terminalize the header

**Files:** Modify `lib/src/mvvm/view/shell/lx_debugger_shell.dart`; update coupled tests.

Behavior:
- Remove the shell-prompt `RichText` (`layerx@dbg ~/<path> $ …`) and `_LxBlinkingCursor` (delete the widget + `_BlinkTween`). New title row: status dot (kept) + plain `Text('Debugger')` + a count chip `'$openProblemCount problems'` (sans, honest). Keep Done / export / ⋯ exactly as-is.
- The pushed Details app bar stays as-is (already plain).
- Grep `lib/` for any other `@dbg`/`\$ `/prompt-styled strings and remove them (report findings).

Required tests: update `shell_p1_ia_test.dart`/`viewer_test.dart`/`shell_redesign_test.dart` selectors if they referenced prompt text (they reference 'Done'/segments/messages — verify); add an assertion in `shell_p1_ia_test.dart` (or new small test) that `'Debugger'` title and `'problems'` count render and that no text containing `'@dbg'` exists. 320px walks stay green. NOTE: with the cursor gone the shell no longer has a perpetual animation — you may simplify bounded pumps where convenient but do NOT switch tests to pumpAndSettle (the FAB pulse still repeats in overlay contexts).

Commit: `feat(viewer): plain header — shell prompt and blinking cursor removed`

---

### Task C: Component restyle + labeled FAB + visible edge handle

**Files:** Modify `lib/src/mvvm/view/shell/lx_ui_kit.dart` (railCard/pill/emptyState/filterSummaryBar edges), `lib/src/config/lx_theme.dart` (snackBar/card decorations if defined there), `lib/src/widgets/lx_fab_trigger.dart` (resting label), `lib/src/widgets/lx_edge_trigger.dart` (visible handle); update coupled tests.

Behavior:
- **Cards/pills/chips/snackBar:** per §4.5 — visible separation (stronger borders or subtle elevation on the new neutral surfaces), consistent radius tokens. `railCard` keeps square corners + left rail (constraint documented in its comment) but its top/right/bottom borders become clearly visible against the new surfaces.
- **FAB resting label:** the FAB becomes a pill-shaped control: bug icon + `'Report a bug'` text label at rest (per §4.5/P3 task 5). Keep: drag, tap-to-open, long-press menu, badge, error color-swap (label may switch to `'{n} problems'`? NO — keep it simple: static label, badge carries the count). Constrain width so a 320px screen fits it with margins; update the default resting offset for the wider shape; drag clamping adapts to the new width.
- **Edge trigger:** make the hairline a visible rounded handle (~4×48, centered on the edge, using the new border-active token) — still swipeable, same gesture.
- FAB-coupled tests (`viewer_test.dart` badge/visibility, `fab_auto_install_test.dart`, `unified_count_test.dart`) must stay green — they find by icon/badge text, verify; update only if the finder was shape-dependent.

Required tests: FAB shows the 'Report a bug' label at rest (new assertion in `viewer_test.dart` or `unified_count_test.dart`); existing badge tests green; 320px walk green.

Commit: `feat(viewer): visible component edges, labeled report-a-bug FAB, visible edge handle`

---

### Task D: Release 1.8.0

- `pubspec.yaml` → `1.8.0`; CHANGELOG (above `## 1.7.0`):

```markdown
## 1.8.0

### Changed

- **UX P3: calm, readable, accessible.** The Neo-Terminal skin is retired: a
  neutral high-contrast dark palette where every load-bearing text token meets
  WCAG AA (≥4.5:1) — enforced by a contrast unit test — with crashes/fatals as
  the most prominent color in the system. The shell prompt and blinking cursor
  are gone (plain "Debugger" title + honest problem count), monospace is
  reserved for payloads and stack traces, cards/pills/snackbars have visible
  edges, the floating button is now a labeled **"Report a bug"** pill, and the
  edge-swipe affordance is a visible handle.
```

- Full verify + dry-run (0 warnings) → commit `chore(viewer): release 1.8.0 — calm high-contrast theme (UX P3)` → publish → merge → push.

---

## Self-Review
- Roadmap P3 map: 1→A (palette+gate), 2→B (de-terminalize), 3→A (typography), 4→C (components), 5→C (FAB+edge). Acceptance coverage: ≥4.5:1 (A's gate test), no prompt/@dbg/$/cursor (B's assertion + grep), FAB readable label (C's test), mono only for payloads/stack (A tokens + existing payload styles).
- Kept dark-neutral identity deliberately (documented rationale above); §4's values govern the rest.
