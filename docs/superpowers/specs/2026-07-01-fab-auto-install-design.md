# FAB Auto-Install — Design

**Date:** 2026-07-01
**Status:** Approved (approach chosen by user: runtime auto-install)
**Type:** Bug fix + robustness (FAB missing on apps that already have a `builder:`)

## Problem / root cause

The in-app debug FAB (`LxFabTrigger`) is rendered by `LayerXDebugOverlay`, which
must wrap the app via `MaterialApp.builder`. The setup CLI only injects that
`builder:` when the app doesn't already declare one (see
`bin/src/integration/app_widget_binder.dart` — `if (!hasBuilder)`), otherwise it
skips and just prints a warning. **Almost every real GetX app already has a
`builder:`** (ScreenUtil, MediaQuery, EasyLoading…), so `LayerXDebugOverlay` is
never mounted and the FAB never appears — on every such app. Meanwhile
`initialize()` still runs and prints the `[LayerX Debugger] ✓ …` banner, so it
*looks* enabled but shows no FAB.

The package's FAB code itself is unchanged and correct (widget test passes); the
gap is purely in how the overlay gets wired.

## Goal

The FAB must appear on **every** LayerX app with **zero `builder:` wiring**,
with correct z-order across navigation, and never a double FAB.

## Non-goals

- Changing the FAB's look/behavior. Reuse `LxFabTrigger` / `LxEdgeTrigger`.
- Changing the setup CLI's builder logic (left as-is; the runtime path makes it
  unnecessary for the FAB).

## Design

Insert the triggers into the app's **root `Overlay`** at runtime instead of
depending on `builder:` wiring.

### `LayerXOverlayInstaller` (new: `lib/src/widgets/lx_overlay_installer.dart`)

A static coordinator holding a single `OverlayEntry`:

- `installInto(OverlayState overlay)` — idempotent. If not installed, insert a
  new entry (`LxTriggerLayer`) into `overlay`. If already installed in the same
  overlay, `bringToFront()`. Gated on `LayerXDebugger.config.viewerEnabled`.
- `bringToFront()` — `entry.remove(); overlay.insert(entry)` to keep the FAB
  above newly-pushed routes (called on every route change).
- `ensure()` — best-effort fallback: on a post-frame callback, find the root
  `Overlay` by walking from `WidgetsBinding.instance.rootElement` to the first
  `NavigatorState` (`.overlay`); retry a few frames if not ready yet.
- `reset()` — remove the entry (tests / hot-restart).

`LxTriggerLayer` (widget, same file): reads config; `SizedBox.shrink()` when
`!viewerEnabled`; else a `Positioned.fill` → `Stack` with `LxEdgeTrigger`
(if `enableEdgeSwipe`) and `LxFabTrigger` (if `enableFloatingButton`), all hidden
via a `ValueListenableBuilder` on `LayerXViewerState.isOpen` while the shell is
open. Only this layer renders triggers, so there is never a double FAB.

### Wiring (three entry points, all idempotent → one entry)

1. **Route observer** (primary, correct z-order): `LayerXRouteObserver` calls
   `LayerXOverlayInstaller.installInto(navigator!.overlay!)` on `didPush` /
   `didReplace` / `didPop` (guarded for nulls). First push inserts; later ones
   bring-to-front. Setup already wires this observer, so it covers the user's
   apps.
2. **`LayerXDebugOverlay`** becomes a passthrough: `build` schedules a
   post-frame `installInto(Overlay.of(context, rootOverlay: true))` and returns
   `child` (no more Stack/triggers of its own). Backward compatible for apps
   that already wrap it — same FAB, no double.
3. **`initialize()`**: if `config.viewerEnabled`, call `ensure()` (element-walk
   fallback) for apps that have neither the observer nor the overlay wrapper.

### FAB position persistence

`bringToFront()` re-inserts the entry, which recreates `LxFabTrigger`'s state.
To avoid the FAB jumping / re-animating on every navigation, lift its dragged
`_offset` to a `static` and gate the mount animation to run once (a static
`bool`).

### Safety

- Every install path is wrapped so a failure degrades to "no FAB", never a
  crash (consistent with the existing never-crash guard).
- When the debugger shell (a pushed route) is open, `isOpen` hides the triggers
  even though the entry is on top.
- Config gates (`viewerEnabled`, `enableFloatingButton`, `enableEdgeSwipe`,
  `prod` environment) are all honored inside `LxTriggerLayer` and `installInto`.

## Testing

Widget tests (VM):
- **Zero-wiring:** pump `MaterialApp(navigatorObservers: [LayerXDebugger.routeObserver], home: Scaffold())` with NO `LayerXDebugOverlay`; after frames, the FAB (`LxFabTrigger`) is present. Proves the fix.
- **No double:** same app but also wrapping with `LayerXDebugOverlay` → exactly one `LxFabTrigger`.
- **Hidden when open:** with `LayerXViewerState.isOpen = true`, no visible trigger.
- Reset installer + viewer state + saved offset in `setUp`/`tearDown`.

## Rollout

Patch release **1.4.1** (fixes broken FAB; no new public API — `LayerXDebugOverlay`
still exists). CHANGELOG note. Existing `LayerXDebugOverlay` users unaffected.
