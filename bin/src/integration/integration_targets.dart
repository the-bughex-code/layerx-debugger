/// Typed result of scanning a LayerX project for the services the setup CLI
/// must bind to: the logger, a Dio client, and/or an `http`-based wrapper.

class LoggerTarget {
  final bool found;
  final String? filePath;
  final String? className;
  const LoggerTarget._(this.found, this.filePath, this.className);
  const LoggerTarget.notFound() : this._(false, null, null);
  const LoggerTarget.at(String path, String name) : this._(true, path, name);
}

class DioTarget {
  final bool found;
  final String? filePath;
  const DioTarget._(this.found, this.filePath);
  const DioTarget.notFound() : this._(false, null);
  const DioTarget.at(String path) : this._(true, path);
}

class HttpWrapTarget {
  final bool found;
  final String? filePath;
  final String? className;
  const HttpWrapTarget._(this.found, this.filePath, this.className);
  const HttpWrapTarget.notFound() : this._(false, null, null);
  const HttpWrapTarget.at(String path, String name)
      : this._(true, path, name);
}

class IntegrationTargets {
  final LoggerTarget logger;
  final DioTarget dio;
  final HttpWrapTarget httpWrap;
  const IntegrationTargets({
    required this.logger,
    required this.dio,
    required this.httpWrap,
  });
  bool get anyHttp => dio.found || httpWrap.found;
}
