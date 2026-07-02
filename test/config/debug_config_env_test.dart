import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/enums/layerx_environment.dart';
import 'package:layerx_debugger/src/config/layerx_debug_config.dart';

void main() {
  group('environment resolution', () {
    test('defaults to prod in release, dev otherwise', () {
      expect(LayerXDebugConfig.resolveEnvironment(null, isRelease: true),
          LayerXEnvironment.prod);
      expect(LayerXDebugConfig.resolveEnvironment(null, isRelease: false),
          LayerXEnvironment.dev);
    });

    test('an explicit environment always wins', () {
      expect(
        LayerXDebugConfig.resolveEnvironment(LayerXEnvironment.staging,
            isRelease: true),
        LayerXEnvironment.staging,
      );
      expect(
        LayerXDebugConfig.resolveEnvironment(LayerXEnvironment.dev,
            isRelease: true),
        LayerXEnvironment.dev,
      );
    });

    test('under test (debug) the default config has the viewer enabled', () {
      // Tests run in debug (kReleaseMode == false), so the default resolves to
      // dev and the viewer/FAB is available — unchanged behavior for devs.
      expect(const LayerXDebugConfig().environment, LayerXEnvironment.dev);
      expect(const LayerXDebugConfig().viewerEnabled, isTrue);
    });

    test('an explicit prod config disables the viewer', () {
      const cfg = LayerXDebugConfig(environment: LayerXEnvironment.prod);
      expect(cfg.environment, LayerXEnvironment.prod);
      expect(cfg.viewerEnabled, isFalse);
    });
  });
}
