import 'package:get/get.dart';

import 'layerx_debug_mixin.dart';

/// A drop-in [GetxController] whose lifecycle is logged by LayerX.
///
/// Extend it instead of `GetxController` to get automatic `onInit`/`onReady`/
/// `onClose` logging with no extra code:
///
/// ```dart
/// class HomeController extends LayerXController {}
/// ```
abstract class LayerXController extends GetxController with LayerXDebugMixin {}
