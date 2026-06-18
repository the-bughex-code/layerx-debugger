/// Opt-in Dio integration for LayerX Debugger.
///
/// Import this entrypoint only in projects that use `dio`:
/// ```dart
/// import 'package:layerx_debugger/dio.dart';
///
/// final dio = Dio();
/// dio.interceptors.add(LayerXDioInterceptor());
/// ```
library;

export 'src/services/network/layerx_dio_interceptor.dart';
