/// Pure source transform that wires `LayerXDebugOverlay` and the LayerX route
/// observer into a `MaterialApp` / `GetMaterialApp` constructor.
///
/// Kept free of `dart:io` so it can be unit tested directly (mirrors the
/// `bindDio` / `bindHttpClient` binders).
library;

const _importLine = "import 'package:layerx_debugger/layerx_debugger.dart';";

/// Outcome of [bindAppWidget].
class AppWidgetBindResult {
  /// The transformed source.
  final String source;

  /// True when the app already declared its own `builder:`, so the overlay
  /// builder was intentionally NOT injected (a second `builder:` would be a
  /// duplicate named argument and fail to compile). The caller should tell the
  /// user to wrap their existing builder's child with `LayerXDebugOverlay`.
  final bool builderSkipped;

  const AppWidgetBindResult(this.source, {required this.builderSkipped});
}

final _appPattern = RegExp(r'\b(GetMaterialApp|MaterialApp)\s*\(');

/// Injects the LayerX overlay builder + route observer into every
/// `MaterialApp`/`GetMaterialApp` in [source].
///
/// Only injects a parameter the app does not already declare: if a `builder:`
/// or `navigatorObservers:` is already present at the top level of the call, it
/// is left untouched so we never emit a duplicate named argument. Returns null
/// when there is no app widget or it is already wrapped.
AppWidgetBindResult? bindAppWidget(String source) {
  if (source.contains('LayerXDebugOverlay')) return null;
  if (!_appPattern.hasMatch(source)) return null;

  var content = source;
  var builderSkipped = false;

  // Work backwards so earlier string indices stay valid after each insertion.
  final matches = _appPattern.allMatches(content).toList().reversed;
  for (final match in matches) {
    final parenIdx = match.end - 1; // index of the `(`
    if (parenIdx >= content.length || content[parenIdx] != '(') continue;

    final closeIdx = _findMatchingParen(content, parenIdx);
    if (closeIdx == -1) continue;

    final lineStart = content.lastIndexOf('\n', parenIdx) + 1;
    final lineContent = content.substring(lineStart, parenIdx);
    final indent = ' ' * (lineContent.length - lineContent.trimLeft().length);
    final paramIndent = '$indent  ';

    final hasBuilder = _hasTopLevelArg(content, parenIdx, closeIdx, 'builder');
    final hasObservers =
        _hasTopLevelArg(content, parenIdx, closeIdx, 'navigatorObservers');

    final params = <String>[];
    if (!hasBuilder) {
      params.add('${paramIndent}builder: (context, child) =>'
          ' LayerXDebugOverlay(child: child!),');
    } else {
      builderSkipped = true;
    }
    if (!hasObservers) {
      params.add(
          '${paramIndent}navigatorObservers: [LayerXDebugger.routeObserver],');
    }
    if (params.isEmpty) continue;

    final injection = '\n${params.join('\n')}';
    content = content.substring(0, parenIdx + 1) +
        injection +
        content.substring(parenIdx + 1);
  }

  content = _injectImport(content);
  return AppWidgetBindResult(content, builderSkipped: builderSkipped);
}

/// Inserts the LayerX import after the last existing import line.
String _injectImport(String content) {
  if (content.contains(_importLine)) return content;
  final matches =
      RegExp(r"^import\s+'[^']+';", multiLine: true).allMatches(content);
  if (matches.isEmpty) return '$_importLine\n\n$content';
  final last = matches.last;
  return '${content.substring(0, last.end)}\n$_importLine'
      '${content.substring(last.end)}';
}

/// Whether the call spanning ([openParen], [closeParen]) declares a top-level
/// named argument `name:` — i.e. one nested directly in the call, not inside a
/// nested constructor/collection. Guards against duplicating `builder:` /
/// `navigatorObservers:` the app already sets.
bool _hasTopLevelArg(String s, int openParen, int closeParen, String name) {
  final re = RegExp('\\b$name\\s*:');
  var depth = 0;
  for (var i = openParen; i < closeParen; i++) {
    final c = s[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 1 && re.matchAsPrefix(s, i) != null) {
      return true;
    }
  }
  return false;
}

int _findMatchingParen(String s, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
