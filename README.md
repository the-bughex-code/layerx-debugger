# layerx_debugger

[![pub package](https://img.shields.io/pub/v/layerx_debugger.svg)](https://pub.dev/packages/layerx_debugger)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)
[![style: flutter_lints](https://img.shields.io/badge/style-flutter__lints-40c4ff.svg)](https://pub.dev/packages/flutter_lints)

A **drop-in debugger and logger for Flutter & GetX**. One call to
`LayerXDebugger.initialize()` gives you pretty console logs, automatic
Dio/`http` capture, crash handling, route, widget and performance tracking, and
a beautiful **in-app log viewer** with blame analysis and API response diffing.

Originally extracted from a production ride-hailing app, generalised for any
Flutter project.

---

## ✨ Features

| | |
|---|---|
| 🎨 **Pretty console logs** | `LayerXLog.d/i/w/e/s` with colors, emojis & timestamps |
| 📦 **Boxed API logs** | `┌─ │ └` request/response/error blocks |
| 🌐 **Network capture** | `LayerXHttp` (`http`, **primary**) + an optional Dio recipe — **no forced dio dependency** |
| 🔒 **Secret masking** | `password`, `token`, `authorization`, `apiKey`, `secret` (+ your own) → `********` |
| 💥 **Crash handling** | `FlutterError`, `PlatformDispatcher` & zoned errors, with an `onCrash` hook for Crashlytics/Sentry |
| 🧭 **Route logging** | `LayerXRouteObserver` (Navigator) + `LayerXRouteMiddleware` (GetX) |
| 🧩 **GetX integration** | `LayerXController`, `LayerXService`, `LayerXDebugMixin` + auto-registered GetX services |
| 🔎 **Auto setup & detection** | One `initialize()` detects LayerX/GetX, injects services (with duplicate & double-init guards), and activates modules incrementally |
| 📲 **Screen & action logs** | `LayerXLog.screen('HomeView')`, `LayerXLog.action('Login tapped')` |
| ⏱ **Profiling** | `LayerXProfiler.start/end/measure` |
| 🔁 **Widget rebuilds** | `LayerXDebugWidget(tag: …)` rebuild counter |
| 🐛 **In-app viewer** | Draggable FAB, edge swipe, searchable list, rich detail, "Who owns this bug?" blame engine, schema diff |
| 🌱 **Environments** | `dev` / `staging` / `prod` control verbosity, colors & the viewer |

## 📦 Installation

```yaml
dependencies:
  layerx_debugger: ^1.0.0
```

```dart
import 'package:layerx_debugger/layerx_debugger.dart';
```

## 🚀 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  LayerXDebugger.runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LayerXDebugger.initialize(
      config: const LayerXDebugConfig(appName: 'My App'),
    );
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorObservers: [LayerXDebugger.routeObserver],
      builder: (context, child) => LayerXDebugOverlay(child: child!),
      home: const HomeView(),
    );
  }
}
```

That's it — a floating 🐛 button now appears in debug builds; tap it (or swipe
in from the right edge) to open the log viewer.

## 📝 Logging

```dart
LayerXLog.d('User fetched');        // debug   (grey)
LayerXLog.i('Cache warmed');        // info    (blue)
LayerXLog.s('Payment captured');    // success (green)
LayerXLog.w('Retrying request');    // warning (amber)
LayerXLog.e('API error', error: e, stackTrace: st); // error (red)

// Or log any value inline:
'Saved!'.logS();
response.statusCode.logD();
```

Need full structure for the viewer? Use `LayerXLog.log(...)`:

```dart
LayerXLog.log(
  level: LayerXLogLevel.error,
  message: 'Checkout failed',
  screen: 'CheckoutView',
  controller: 'CheckoutController',
  endpoint: '/orders',
  statusCode: 500,
  error: e,
  stackTrace: st,
);
```

### Console output

```text
┌────────────────────────────────────────────────────────────
│ API GET /users
│ Status   : 200 OK • 142ms
│ Response : {"id":1,"name":"Ada"}
└────────────────────────────────────────────────────────────
```

Colors map to: **blue** = info, **green** = success, **amber** = warning,
**red** = error, **grey** = debug. They are disabled automatically in
production.

## 🌐 HTTP Integration (primary)

`http` is the primary, zero-config networking integration — just swap the
top-level `http` calls for `LayerXHttp`:

```dart
final res = await LayerXHttp.get(Uri.parse('https://api.example.com/users'));
await LayerXHttp.post(uri, headers: headers, body: jsonBody);
// get / post / put / patch / delete are all supported.
```

Every request/response/error is logged with method, URL, headers, body, status,
duration and a fix suggestion on failure. Sensitive fields are masked.

## 🧩 Dio (optional — no forced dependency)

LayerX deliberately does **not** depend on `dio`, so it's never forced on apps
that use plain `http`. If your app already uses Dio, add a tiny interceptor that
forwards to the public `LayerXNetworkLogger`:

```dart
import 'package:dio/dio.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

class LayerXDioInterceptor extends Interceptor {
  @override
  void onResponse(Response res, ResponseInterceptorHandler handler) {
    LayerXNetworkLogger.record(
      endpoint: res.requestOptions.uri.toString(),
      method: res.requestOptions.method,
      statusCode: res.statusCode ?? 0,
      responseBody: res.data?.toString(),
      requestBody: res.requestOptions.data?.toString(),
      requestHeaders: res.requestOptions.headers
          .map((k, v) => MapEntry(k, '$v')),
    );
    handler.next(res);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    LayerXNetworkLogger.recordException(
      endpoint: err.requestOptions.uri.toString(),
      method: err.requestOptions.method,
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}

final dio = Dio()..interceptors.add(LayerXDioInterceptor());
```

## 🔎 Automatic setup & detection

`initialize()` detects whether the app is a LayerX/GetX app and, if so,
auto-registers the LayerX GetX services (`LayerXLoggerService`,
`LayerXDebugService`, `LayerXCrashService`, `LayerXNetworkService`,
`LayerXPerformanceService`, `LayerXRouteService`) as permanent singletons —
with duplicate-prevention and a double-initialization guard. It then prints a
banner:

```text
[LayerX Debugger]

✓ LayerX architecture detected
✓ GetX detected
✓ UI detected
✓ Services registered
⚠ Controllers not found yet
⚠ API layer not found yet

Debugger initialized with partial integration.
```

Modules light up **incrementally**: the first time a `LayerXController` runs or
an HTTP request is logged, that module activates automatically. In a non-LayerX
app, set `isLayerXArchitecture: false` (or `autoInject: false`) and LayerX
injects nothing and only prints guidance — it never alters app behavior.

## 📲 Screen & Action Logging

```dart
LayerXLog.screen('HomeView');          // [SCREEN] HomeView opened
LayerXLog.action('Login Button Clicked'); // [ACTION] Login Button Clicked
```

## 🧩 GetX Integration

```dart
// Extend the base classes…
class HomeController extends LayerXController {}
class AuthService   extends LayerXService {}

// …or mix into an existing controller:
class CartController extends GetxController with LayerXDebugMixin {}
```

`onInit`, `onReady` and `onClose` are logged automatically.

## 🧭 Route Debugging

```dart
// Navigator / GetX (app-wide):
GetMaterialApp(navigatorObservers: [LayerXDebugger.routeObserver]);

// GetX per-page middleware:
GetPage(name: '/home', page: () => HomeView(), middlewares: [LayerXRouteMiddleware()]);
```

## 💥 Crash Handling

`initialize()` installs global handlers for `FlutterError.onError` and
`PlatformDispatcher.onError`, and `LayerXDebugger.runZonedGuarded` captures
uncaught async errors. Forward everything to your reporter via `onCrash`:

```dart
await LayerXDebugger.initialize(
  config: LayerXDebugConfig(
    onCrash: (error, stack, fatal) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
      // or: Sentry.captureException(error, stackTrace: stack);
    },
  ),
);
```

> Crashlytics and Sentry are **optional** — the package has no dependency on
> them and works completely standalone.

## ⏱ Performance Monitoring

```dart
final users = await LayerXProfiler.measure('fetchUsers', () => api.fetchUsers());

LayerXProfiler.start('render');
// ... work ...
LayerXProfiler.end('render');
```

## 🔁 Widget Monitoring

```dart
LayerXDebugWidget(
  tag: 'HomeView',
  child: HomeView(),
); // logs "HomeView rebuilt N times"
```

## ⚙️ Configuration

```dart
await LayerXDebugger.initialize(
  config: LayerXDebugConfig(
    appName: 'My App',
    environment: LayerXEnvironment.dev, // dev / staging / prod
    enableApiLogs: true,
    enableRouteLogs: true,
    enableCrashLogs: true,
    enableGetXLogs: true,
    enablePerformanceLogs: true,
    enableWidgetLogs: true,
    maskKeys: ['ssn', 'cardNumber'],
    maxStoredLogs: 500,
    edgeSwipeZone: LayerXEdgeZone.right,
    autoInject: true,            // auto-register the GetX services
    isLayerXArchitecture: null,  // null = auto (assume LayerX); false = skip
    onCrash: (e, s, fatal) {/* forward */},
  ),
);
```

| Environment | Console level | Colors | In-app viewer |
|---|---|---|---|
| `dev` | verbose+ | ✅ | ✅ |
| `staging` | info+ | ✅ | ✅ |
| `prod` | warning+ | ❌ | ❌ |

## 🐛 In-App Viewer

The viewer (opened from the floating button, an edge swipe, or
`LayerXDebugSettingsButton`) provides:

- a searchable, filterable, color-coded log list with a session-health banner;
- a rich detail screen with request/response payloads, JSON syntax highlighting
  and a **field-level API response diff**;
- a **"Who owns this bug?"** blame analysis (app vs backend vs network);
- a suggested-fix card and a step-by-step journey timeline;
- one-tap export of all logs to the clipboard.

## 📸 Screenshots

> Screenshots and a demo GIF live in [`doc/`](doc/). _(Add `doc/viewer.png`,
> `doc/detail.png` and `doc/demo.gif` to showcase the viewer on pub.dev.)_

## 📖 Example

A complete GetX example lives in [`example/`](example/). Run it with:

```bash
cd example && flutter pub get && flutter run
```

## 🤝 Contributing

Issues and PRs are welcome at
<https://github.com/the-bughex-code/layerx_debugger>.

## 📄 License

BSD-3-Clause © The BugHex. See [LICENSE](LICENSE).
