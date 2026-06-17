import 'package:get/get.dart';

import 'package:layerx_debugger/src/core/mixins/layerx_debug_mixin.dart';

/// A drop-in [GetxService] whose lifecycle is logged by LayerX.
///
/// Extend it instead of `GetxService` for permanent services that should be
/// traced:
///
/// ```dart
/// class AuthService extends LayerXService {}
/// ```
abstract class LayerXService extends GetxService with LayerXDebugMixin {}
