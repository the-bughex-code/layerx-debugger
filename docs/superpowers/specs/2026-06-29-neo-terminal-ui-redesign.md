# Viewer UI redesign — "Neo Terminal"

**Date:** 2026-06-29
**Status:** Implemented (user picked direction B, default neon green/cyan accent)
**Scope:** in-app viewer UI of `layerx_debugger` only — no data/model/API changes.

## Goal

Replace the current viewer look with a brand-new **Neo Terminal** aesthetic:
pure-black base, neon green primary accent + cyan secondary, monospace-forward,
left-accent rows, fully animated, and **zero overflow** on any screen size.
Same four destinations (Dashboard/Pulse, Network, Console, Inspector) and the
same data wiring — only the presentation and motion change.

## Strategy (highest leverage first)

1. **`lx_theme.dart`** — rewrite the palette to Neo Terminal values while keeping
   every token *name* identical, so the restyle cascades through all widgets
   with no breakage.
2. **`lx_bottom_nav.dart`** — animated sliding indicator, monospace labels,
   active neon glow.
3. **`lx_debugger_shell.dart`** — a terminal command-bar header
   (`layerx@debugger ~ $ <path>` + live count + blinking cursor) and an animated
   fade-through page transition between destinations.
4. **`lx_ui_kit.dart`** — terminal restyle of `pill` / `railCard` / `emptyState`,
   plus a reusable `LxKit.stagger(index, child)` entrance animation
   (fade + slide-up) used by the list panes.
5. **Panes** — wrap list items in the stagger animation and audit every row for
   overflow (`Expanded` + `TextOverflow.ellipsis`, `SafeArea`, scrollable bodies).

## Motion language

- Page switch: fade-through (AnimatedSwitcher), ~220 ms.
- Bottom nav: indicator slides to the active item, ~260 ms easeOutCubic.
- List rows: staggered fade + 8px slide-up, capped delay so long lists stay snappy.
- Header cursor: 1 s blink.
- Existing FAB pulse/mount animations are retained (restyled via theme).

## Overflow rules (applied everywhere)

- Every horizontal row: flexible/expanded middle, `maxLines: 1` + ellipsis on text.
- Bodies scroll; nothing relies on a fixed height that can exceed the viewport.
- `SafeArea` on the shell and bottom nav.

## Out of scope

API-capture fix (shipped separately), crash fix, compatibility gate.
