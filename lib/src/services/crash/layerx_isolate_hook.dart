/// Platform-neutral entry point for the isolate error hook.
///
/// Resolves to the `dart:isolate` implementation on native platforms and a
/// no-op on the web (where `dart:isolate` is unavailable).
library;

export 'layerx_isolate_hook_stub.dart'
    if (dart.library.io) 'layerx_isolate_hook_io.dart';
