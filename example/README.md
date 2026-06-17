# layerx_debugger example

A small GetX app that demonstrates every feature of `layerx_debugger`:

- `LayerXLog.d/i/w/e/s` console + in-app logging
- `LayerXDioInterceptor` and `LayerXHttp` network capture with sensitive-field masking
- `LayerXController` GetX lifecycle logging
- `LayerXProfiler` performance measurement
- `LayerXDebugWidget` rebuild counting
- `LayerXRouteObserver` navigation logging
- Global crash capture via `LayerXDebugger.runZonedGuarded` + `onCrash`
- The in-app viewer (`LayerXDebugOverlay`, floating button, edge swipe) and
  `LayerXDebugSettingsButton`

## Run

```bash
cd example
flutter pub get
flutter run
```

Tap the buttons, then open the floating 🐛 button (or swipe in from the right
edge) to explore the captured logs, blame analysis and API diffs.
