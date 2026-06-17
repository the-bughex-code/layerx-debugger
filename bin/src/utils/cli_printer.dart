/// ANSI-colored console output utilities for the LayerX setup CLI.
// ignore_for_file: avoid_print
library;

// ANSI escape codes
const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _cyan = '\x1B[36m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _red = '\x1B[31m';
const _magenta = '\x1B[35m';
const _dim = '\x1B[2m';

class CliPrinter {
  static void header() {
    print('');
    print(
      '$_bold$_cyan'
      '  ██╗      █████╗ ██╗   ██╗███████╗██████╗ ██╗  ██╗'
      '$_reset',
    );
    print(
      '$_bold$_cyan'
      '  ██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗╚██╗██╔╝'
      '$_reset',
    );
    print(
      '$_bold$_cyan'
      '  ██║     ███████║ ╚████╔╝ █████╗  ██████╔╝ ╚███╔╝ '
      '$_reset',
    );
    print(
      '$_bold$_cyan'
      '  ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗ ██╔██╗ '
      '$_reset',
    );
    print(
      '$_bold$_cyan'
      '  ███████╗██║  ██║   ██║   ███████╗██║  ██║██╔╝ ██╗'
      '$_reset',
    );
    print(
      '$_bold$_cyan'
      '  ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝'
      '$_reset',
    );
    print('  $_dim$_cyan Debugger Setup Tool v1.0.0$_reset');
    print('');
  }

  static void step(String message) {
    print('$_bold$_cyan  ▶  $message$_reset');
  }

  static void success(String message) {
    print('$_green  ✅  $message$_reset');
  }

  static void skip(String message) {
    print('$_dim  ⏭   $message (already configured — skipping)$_reset');
  }

  static void warning(String message) {
    print('$_yellow  ⚠️   $message$_reset');
  }

  static void error(String message) {
    print('$_red  ❌  $message$_reset');
  }

  static void info(String message) {
    print('$_dim  ℹ   $message$_reset');
  }

  static void divider() {
    print('$_dim  ─────────────────────────────────────────$_reset');
  }

  static void summary({
    required bool pubspecDone,
    required bool mainDone,
    required String? appWidgetFile,
    bool servicesBound = false,
  }) {
    print('');
    divider();
    print('$_bold$_magenta  🎉  Setup Complete!$_reset');
    divider();
    if (pubspecDone) success('layerx_debugger added to pubspec.yaml');
    if (mainDone) success('main.dart wrapped with LayerXDebugger');
    if (appWidgetFile != null) {
      success('LayerXDebugOverlay injected in $appWidgetFile');
    }
    if (servicesBound) {
      success('LoggerService & HttpsCalls bound to LayerX Debugger');
    }
    print('');
    print('$_bold  Next steps:$_reset');
    print('  $_cyan 1.$_reset  Run $_bold`flutter pub get`$_reset if not done');
    print(
      '  $_cyan 2.$_reset  Run $_bold`flutter run`$_reset — '
      'look for the LayerX FAB button 🐛',
    );
    print(
      '  $_cyan 3.$_reset  Customize config in main.dart via '
      '${_bold}LayerXDebugConfig(...)$_reset',
    );
    print('');
  }
}
