/// Web/no-op fallback: isolates are not available, so this does nothing.
void Function() installIsolateErrorHook(
        void Function(Object error, StackTrace stack) onError) =>
    () {};
