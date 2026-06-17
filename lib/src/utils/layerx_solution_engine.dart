/// Maps common error patterns to actionable developer fix hints.
///
/// The engine is pure and stateless. The log output and network logger run it
/// against error/fatal entries to attach a [LayerXLogEntry.suggestedSolution].
class LayerXSolutionEngine {
  LayerXSolutionEngine._();

  /// Ordered (pattern, suggestion) rules. Matching is first-wins.
  static final List<(RegExp, String)> _rules = [
    (
      RegExp(r'Null check operator used on a null value|null check operator',
          caseSensitive: false),
      'A non-nullable variable (!) was null at runtime. '
          'Add a null guard: use `?.`, `??`, or an explicit null check before accessing this value. '
          'Also verify the backend is not returning null for a field the model treats as required.',
    ),
    (
      RegExp(r'NoSuchMethodError.*null|called on null', caseSensitive: false),
      'A method was called on a null object. '
          'Ensure the object is initialized before use. '
          'If it comes from an API response, add null handling in the fromJson() method.',
    ),
    (
      RegExp(r'RangeError.*index|Invalid value.*index', caseSensitive: false),
      'List index out of bounds. '
          'Add a length check before accessing this index: `if (list.length > index)`.',
    ),
    (
      RegExp(r'Bad state: No element', caseSensitive: false),
      '`firstWhere()` or `single` was called on an empty collection. '
          'Use `firstWhereOrNull()` (collection package) or check `list.isNotEmpty` first.',
    ),
    (
      RegExp(r'Concurrent modification during iteration', caseSensitive: false),
      'A list was mutated while iterating it. '
          'Iterate over a copy: `for (final item in List.from(original))`.',
    ),
    (
      RegExp(r'type.*is not a subtype of type|is not a subtype of',
          caseSensitive: false),
      'Type cast failure — likely a JSON model mismatch. '
          'The backend returned a different type than the Dart model expects (e.g., int vs String). '
          'Add explicit casting in fromJson() and check the backend API response.',
    ),
    (
      RegExp(
          r'FormatException.*json|Unexpected character|FormatException.*Unexpected',
          caseSensitive: false),
      'The server returned non-JSON content (HTML error page, empty body, or malformed JSON). '
          'Check the Response Payload in this log. '
          'The server may be returning an HTML 500 error instead of a JSON response.',
    ),
    (
      RegExp(r'fromJson|deserialization|json.decode', caseSensitive: false),
      'JSON deserialization failed. '
          'Compare the actual response payload with your Dart model\'s fromJson() method. '
          'Look for renamed, removed, or type-changed fields.',
    ),
    (
      RegExp(
          r'SocketException|Connection refused|Network is unreachable|Failed host lookup|No route to host',
          caseSensitive: false),
      'Device cannot reach the server. '
          'Check: (1) device internet connection, (2) correct base URL in config, '
          '(3) server is running and accessible from outside. '
          'Test the endpoint in Postman to isolate network vs server issue.',
    ),
    (
      RegExp(
          r'TimeoutException|DioException.*timeout|connect timeout|receive timeout|send timeout',
          caseSensitive: false),
      'Network request timed out. '
          'Check: (1) Dio timeout config (connectTimeout / receiveTimeout), '
          '(2) server response time in Postman. '
          'If Postman is slow → backend performance issue. '
          'If Postman is fast → increase app timeout or check interceptor overhead.',
    ),
    (
      RegExp(r'\b408\b'),
      'HTTP 408 Request Timeout — the server closed the connection before the app finished sending. '
          'Check upload payload size and connection stability.',
    ),
    (
      RegExp(r'\b429\b|Too Many Requests|rate.?limit', caseSensitive: false),
      'HTTP 429 Too Many Requests. '
          'Check if there is an infinite retry loop in the app\'s error interceptor. '
          'Add exponential backoff or throttling before retrying failed requests.',
    ),
    (
      RegExp(r'\b401\b|Unauthorized|Unauthenticated', caseSensitive: false),
      'Auth token missing or expired. '
          'Verify: (1) token is attached in Dio\'s Authorization header, '
          '(2) refresh-token logic is working correctly. '
          'Log out and log back in to test with a fresh token.',
    ),
    (
      RegExp(r'\b403\b|Forbidden|Access denied', caseSensitive: false),
      'HTTP 403 — user lacks permission for this resource. '
          'Check the user\'s role in the database. '
          'If role is correct, the backend ACL/permission configuration needs review.',
    ),
    (
      RegExp(r'\b404\b|not found|No such route', caseSensitive: false),
      'HTTP 404 — endpoint URL does not exist. '
          'Copy the endpoint from the log and test in Postman. '
          'If Postman also gets 404, the backend route was deleted or renamed without notifying the mobile team.',
    ),
    (
      RegExp(r'\b422\b|Unprocessable Entity|validation failed|invalid.*field',
          caseSensitive: false),
      'HTTP 422 — backend validation rejected the request body. '
          'Compare the Request Payload in this log against the API documentation. '
          'Look for missing required fields, wrong data types, or renamed keys.',
    ),
    (
      RegExp(r'\b400\b|Bad Request|malformed', caseSensitive: false),
      'HTTP 400 Bad Request. '
          'Check the request payload for missing or malformed fields. '
          'Ensure enums, dates, and nested objects match the API schema exactly.',
    ),
    (
      RegExp(r'\b500\b|Internal Server Error', caseSensitive: false),
      'HTTP 500 Internal Server Error — the server crashed. '
          'This is NOT a mobile bug. '
          'Share the endpoint, request payload, and timestamp with the backend team.',
    ),
    (
      RegExp(r'\b502\b|Bad Gateway', caseSensitive: false),
      'HTTP 502 Bad Gateway. The proxy received an invalid response from the upstream server. '
          'Contact the DevOps / backend team — check nginx/load-balancer and upstream service health.',
    ),
    (
      RegExp(r'\b503\b|Service Unavailable', caseSensitive: false),
      'HTTP 503 Service Unavailable — server is down or under maintenance. '
          'Check the server status page. This is a backend/DevOps issue.',
    ),
    (
      RegExp(r'setState\(\) called after dispose|setState after dispose',
          caseSensitive: false),
      '`setState()` was called on a disposed widget. '
          'Add a mounted check: `if (mounted) setState(() { ... });` '
          'Ensure async callbacks are cancelled in `dispose()`.',
    ),
    (
      RegExp(r'RenderFlex overflowed|overflowed by.*pixel',
          caseSensitive: false),
      'Layout overflow detected. '
          'Wrap the overflowing widget in `Flexible`, `Expanded`, or `SingleChildScrollView`. '
          'Test on smaller screen sizes (320px).',
    ),
    (
      RegExp(r'PlatformException', caseSensitive: false),
      'A native plugin threw a PlatformException. '
          'Check: (1) required permissions are declared in AndroidManifest.xml / Info.plist, '
          '(2) user has granted the permission at runtime, '
          '(3) plugin is correctly initialized.',
    ),
    (
      RegExp(r'Stack Overflow|StackOverflowError', caseSensitive: false),
      'Infinite recursion detected. '
          'Look for a method that calls itself without a proper base case. '
          'Check build() methods that trigger rebuilds in a loop.',
    ),
  ];

  /// Returns the first matching suggestion for [message] + [stackTrace], or
  /// `null` if no rule matches.
  static String? getSuggestion(String message, String? stackTrace) {
    final combined = '$message\n${stackTrace ?? ''}';
    for (final (pattern, suggestion) in _rules) {
      if (pattern.hasMatch(combined)) {
        return suggestion;
      }
    }
    return null;
  }
}
