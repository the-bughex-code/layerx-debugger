import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/layerx_debugger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LayerXDebugConfig', () {
    test('has development-friendly defaults', () {
      const config = LayerXDebugConfig();
      expect(config.enableApiLogs, isTrue);
      expect(config.environment, LayerXEnvironment.dev);
      expect(config.maxStoredLogs, 500);
      expect(config.resolvedUseColors, isTrue);
      expect(config.viewerEnabled, isTrue);
    });

    test('production disables colors and the viewer', () {
      const config = LayerXDebugConfig(environment: LayerXEnvironment.prod);
      expect(config.resolvedUseColors, isFalse);
      expect(config.viewerEnabled, isFalse);
      expect(LayerXEnvironment.prod.minimumLevel, LayerXLogLevel.warning);
    });

    test('useColors override wins over environment', () {
      const config = LayerXDebugConfig(
        environment: LayerXEnvironment.prod,
        useColors: true,
      );
      expect(config.resolvedUseColors, isTrue);
    });
  });

  group('LayerXDebugger', () {
    test('initialize applies config and is repeatable', () async {
      await LayerXDebugger.initialize(
        config: const LayerXDebugConfig(appName: 'First', maxStoredLogs: 10),
      );
      expect(LayerXDebugger.config.appName, 'First');
      expect(LayerXLogStore.maxStoredLogs, 10);

      await LayerXDebugger.initialize(
        config: const LayerXDebugConfig(appName: 'Second'),
      );
      expect(LayerXDebugger.config.appName, 'Second');
    });

    test('runZonedGuarded captures errors and forwards them to onCrash',
        () async {
      bool? fatalFlag;
      await LayerXDebugger.initialize(
        config: LayerXDebugConfig(
          onCrash: (error, stack, fatal) => fatalFlag = fatal,
        ),
      );
      LayerXLogStore.clear();

      LayerXDebugger.runZonedGuarded(() {
        throw StateError('zone boom');
      });

      expect(fatalFlag, isTrue);
      expect(LayerXLogStore.logs, isNotEmpty);
      expect(LayerXLogStore.logs.first.level, LayerXLogLevel.fatal);
      expect(LayerXLogStore.logs.first.message, contains('zone boom'));
    });
  });
}
