import 'dart:isolate';

/// A decoded isolate error.
class IsolateError {
  /// The error message.
  final String message;

  /// The stack trace, or [StackTrace.empty] when none was provided.
  final StackTrace stack;

  /// Creates a decoded isolate error.
  const IsolateError(this.message, this.stack);
}

/// Decodes the `[error, stack]` pair an isolate error listener delivers.
IsolateError decodeIsolateError(List<dynamic> pair) {
  final message = pair.isNotEmpty ? '${pair[0]}' : 'Isolate error';
  final rawStack = pair.length > 1 ? pair[1] : null;
  final stack = rawStack == null
      ? StackTrace.empty
      : StackTrace.fromString(rawStack.toString());
  return IsolateError(message, stack);
}

/// Adds a listener for uncaught errors on the current isolate, forwarding each
/// to [onError]. Returns a close function that removes the listener.
void Function() installIsolateErrorHook(
    void Function(Object error, StackTrace stack) onError) {
  final port = RawReceivePort((dynamic message) {
    final decoded = decodeIsolateError(message as List<dynamic>);
    onError(decoded.message, decoded.stack);
  });
  Isolate.current.addErrorListener(port.sendPort);
  return () {
    Isolate.current.removeErrorListener(port.sendPort);
    port.close();
  };
}
