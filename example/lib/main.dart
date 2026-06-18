import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  // Wrap the app in a guarded zone so uncaught async errors are captured.
  LayerXDebugger.runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LayerXDebugger.initialize(
      config: LayerXDebugConfig(
        appName: 'LayerX Demo',
        packageName: 'layerx_debugger_example',
        maskKeys: const ['ssn'],
        onCrash: (error, stack, fatal) {
          // Forward to Firebase Crashlytics / Sentry here if desired.
        },
      ),
    );
    runApp(const DemoApp());
  });
}

/// Root widget wiring the route observer and the in-app viewer overlay.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'LayerX Debugger Demo',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [LayerXDebugger.routeObserver],
      builder: (context, child) => LayerXDebugOverlay(child: child!),
      home: const HomePage(),
    );
  }
}

/// A GetX controller whose lifecycle is logged automatically.
class DemoController extends LayerXController {
  final count = 0.obs;
  void increment() => count.value++;
}

/// The demo home screen with one button per feature.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DemoController());
    LayerXLog.screen('HomePage');

    return Scaffold(
      appBar: AppBar(title: const Text('LayerX Debugger Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap a button, then open the floating 🐛 button (or swipe from the '
            'right edge) to inspect the logs.',
          ),
          const SizedBox(height: 12),
          _button('Log debug', () => LayerXLog.d('A debug message')),
          _button('Log info', () => LayerXLog.i('An info message')),
          _button('Log success', () => LayerXLog.s('Operation succeeded')),
          _button('Log warning', () => LayerXLog.w('Something looks off')),
          _button(
            'Log error',
            () => LayerXLog.e('Something failed', error: Exception('demo')),
          ),
          _button(
            'Track an action',
            () => LayerXLog.action('Primary CTA tapped'),
          ),
          const Divider(height: 32),
          _button('http GET (success)', _httpGet),
          _button('http POST (masked secrets)', _httpPost),
          _button('Profiler.measure', _profile),
          const Divider(height: 32),
          _button(
            'Uncaught async error (zone)',
            () => Future<void>.error(StateError('async boom')),
          ),
          const Divider(height: 32),
          Obx(
            () => LayerXDebugWidget(
              tag: 'CounterText',
              child: Text(
                'Counter: ${controller.count.value}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          _button(
              'Increment counter (watch rebuild logs)', controller.increment),
          const Divider(height: 32),
          // Open the in-app log viewer from a custom button.
          _button(
            '📋 Open log viewer',
            () => LayerXDebugger.openViewer(context),
          ),
          // Or drop in the ready-made settings tile.
          const LayerXDebugSettingsButton(),
        ],
      ),
    );
  }

  Future<void> _httpGet() async {
    try {
      await LayerXHttp.get(
        Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
      );
    } catch (_) {
      // The wrapper already logged the failure.
    }
  }

  Future<void> _httpPost() async {
    try {
      await LayerXHttp.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Authorization': 'Bearer super-secret-token'},
        body: '{"password":"hunter2","title":"hello"}',
      );
    } catch (_) {
      // The wrapper already logged the failure.
    }
  }

  Future<void> _profile() async {
    await LayerXProfiler.measure(
      'demoJob',
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }

  Widget _button(String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
}
