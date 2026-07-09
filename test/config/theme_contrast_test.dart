import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_category.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';
import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/mvvm/view_model/layerx_blame_engine.dart';

/// WCAG 2.2 contrast gate for the viewer palette (UX P3, plan Task A).
///
/// Every load-bearing text token must reach **AA for body text (≥ 4.5:1)**
/// against every surface it is drawn on. Accents that are decorative-only
/// (rails, icons, borders — never body text) must reach the UI-component
/// floor of **≥ 3.0:1** (WCAG 1.4.11).
///
/// The luminance/contrast math is implemented here on purpose, straight from
/// the spec (https://www.w3.org/TR/WCAG22/#dfn-relative-luminance), so the
/// gate does not depend on Flutter's `computeLuminance` staying conformant.

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) =>
    0.2126 * _linearize(c.r) +
    0.7152 * _linearize(c.g) +
    0.0722 * _linearize(c.b);

/// WCAG contrast ratio, 1.0 (identical) … 21.0 (black on white).
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void _expectContrast(Color fg, Color bg, double min, String pair) {
  final ratio = contrastRatio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$pair: ${_hex(fg)} on ${_hex(bg)} is '
        '${ratio.toStringAsFixed(2)}:1 — needs ≥ $min:1',
  );
}

/// The exact background a `LxTheme.pill(color)` / `LxKit.pill(...)` chip draws
/// its own-colored label on: the pill's tint fill composited over surface. The
/// fill is read straight from `LxTheme.pill` (not a re-hardcoded alpha), so the
/// gate tracks the real production value if that alpha ever changes. Source and
/// category chips render their label *in the accent color on this tint*, so
/// this — not plain surface — is the background the label must clear AA against.
Color _pillTint(Color color) =>
    Color.alphaBlend(LxTheme.pill(color).color!, LxTheme.surface);

/// A minimal [LayerXLogEntry] carrying just the signals the blame engine reads,
/// used to drive `LayerXBlameEngine.analyze()` and read back its verdict color.
LayerXLogEntry _blameEntry({
  required LayerXLogLevel level,
  LayerXLogSource source = LayerXLogSource.backend,
  String message = 'failure',
  int? statusCode,
  bool responseChanged = false,
}) =>
    LayerXLogEntry(
      id: 'x',
      dedupKey: 'x',
      timestamp: DateTime(2026),
      level: level,
      source: source,
      message: message,
      statusCode: statusCode,
      responseChanged: responseChanged,
      journey: const [],
      extras: const {},
    );

void main() {
  const surfaces = <String, Color>{
    'bg': LxTheme.bg,
    'surface': LxTheme.surface,
    'surfaceAlt': LxTheme.surfaceAlt,
    'surfaceHigh': LxTheme.surfaceHigh,
  };

  group('WCAG relative-luminance math sanity', () {
    test('black on white is 21:1, self is 1:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    });
  });

  group('text tokens meet AA (≥ 4.5:1) on every surface they appear on', () {
    const textTokens = <String, Color>{
      'textPrimary': LxTheme.textPrimary,
      'textSecondary': LxTheme.textSecondary,
      // textDim is drawn on real content: timestamps, meta lines, search
      // placeholders, "Showing X of Y". It is a text token, not decoration.
      // (Since UX P3 it is an alias of textTertiary — both stay pinned here.)
      'textDim': LxTheme.textDim,
      'textTertiary': LxTheme.textTertiary,
    };
    for (final text in textTokens.entries) {
      for (final surface in surfaces.entries) {
        test('${text.key} on ${surface.key}', () {
          _expectContrast(
              text.value, surface.value, 4.5, '${text.key}/${surface.key}');
        });
      }
    }
  });

  group('accents used as text meet AA (≥ 4.5:1)', () {
    test('accentRed on surface — error/crash text, metrics, status codes', () {
      _expectContrast(LxTheme.accentRed, LxTheme.surface, 4.5, 'accentRed');
    });
    test('accentRed on every surface — crashes must be the loudest thing', () {
      for (final surface in surfaces.entries) {
        _expectContrast(LxTheme.accentRed, surface.value, 4.5,
            'accentRed/${surface.key}');
      }
    });
    test('critical (crash/fatal) on surface — strongest color on screen', () {
      _expectContrast(LxTheme.critical, LxTheme.surface, 4.5, 'critical');
      _expectContrast(
          LxTheme.criticalOn, LxTheme.surface, 4.5, 'criticalOn/surface');
    });
    test('criticalOn on a critical-tint band (§4.2.5 -on vs own -tint)', () {
      // A tint band is critical at 14% alpha composited over surface.
      final tint = Color.alphaBlend(
          LxTheme.critical.withValues(alpha: 0.14), LxTheme.surface);
      _expectContrast(LxTheme.criticalOn, tint, 4.5, 'criticalOn/criticalTint');
    });
    test('accent (brand) on bg — used for accent text/status on scaffold', () {
      _expectContrast(LxTheme.accent, LxTheme.bg, 4.5, 'accent/bg');
    });
    test('accentInk on accent — label ink ON brand-solid fills (§4.5.5)', () {
      _expectContrast(LxTheme.accentInk, LxTheme.accent, 4.5, 'accentInk');
    });
    test('accentAmber on surface — paused banner text, warnings', () {
      _expectContrast(LxTheme.accentAmber, LxTheme.surface, 4.5, 'accentAmber');
    });
  });

  group('decorative-only accents meet the UI-component floor (≥ 3.0:1)', () {
    // These accents color rails, icons, method/source pills and the edge
    // handle — paired with text/icons elsewhere, never body copy on their
    // own — so WCAG 1.4.11 (3.0:1) is the applicable floor, not 4.5:1.
    const decorative = <String, Color>{
      'accentBlue': LxTheme.accentBlue,
      'accentPurple': LxTheme.accentPurple,
      'accentGreen': LxTheme.accentGreen,
      'accentCyan': LxTheme.accentCyan,
      'accentOrange': LxTheme.accentOrange,
    };
    for (final accent in decorative.entries) {
      test('${accent.key} on surface', () {
        _expectContrast(accent.value, LxTheme.surface, 3.0, accent.key);
      });
    }
  });

  // ── Real render patterns (UX P4, plan Task A0) ─────────────────────────────
  // The gate above pins the raw theme tokens; these four groups pin the enum /
  // blame colors *in the exact composited pattern the viewer paints them in*,
  // so a semantic remap can never regress a chip label or a rail below floor.

  group('source pills — label reads AA (≥ 4.5) on its own 14% tint', () {
    // `LxKit.pill(e.source.label, e.source.color)` paints the label in the
    // source color on `LxTheme.pill(sourceColor)` — an own-color 14% tint.
    for (final source in LayerXLogSource.values) {
      test('${source.name} pill label on its tint', () {
        _expectContrast(source.color, _pillTint(source.color), 4.5,
            '${source.name} source pill');
      });
    }
  });

  group('log levels — rail/icon on surface (≥ 3.0)', () {
    // `e.level.color` colors the row rail (3px border) and the level icon only
    // — decorative use — so the WCAG 1.4.11 component floor (3.0) is the
    // applicable one for every level. Problems/console rows that title error &
    // fatal paint that text in the `LxTheme.accentRed` *token*, not
    // `level.color` (see lx_problems_pane / lx_console_pane), and that text
    // pairing is already pinned above ('accentRed on every surface … ≥ 4.5:1'),
    // so no level needs a 4.5 floor here.
    for (final level in LayerXLogLevel.values) {
      test('${level.name} rail/icon on surface', () {
        _expectContrast(
            level.color, LxTheme.surface, 3.0, '${level.name} level');
      });
    }
  });

  group('category chips — label reads AA (≥ 4.5) on its own 14% tint', () {
    // Category chips follow the same `LxTheme.pill` pattern as source chips:
    // own-color label on an own-color 14% tint.
    for (final category in LayerXLogCategory.values) {
      test('${category.name} chip label on its tint', () {
        _expectContrast(category.color, _pillTint(category.color), 4.5,
            '${category.name} category chip');
      });
    }
  });

  group('blame verdict colors — icon on surface (≥ 3.0)', () {
    // One representative entry per `LayerXBlameEngine.analyze()` branch; the
    // verdict color paints the blame-card icon (decorative — the verdict text
    // uses theme tokens since the P3 hotfix), so the 3.0 component floor holds.
    final cases = <String, LayerXLogEntry>{
      '5xx (500)': _blameEntry(level: LayerXLogLevel.fatal, statusCode: 500),
      '503': _blameEntry(level: LayerXLogLevel.fatal, statusCode: 503),
      '502': _blameEntry(level: LayerXLogLevel.fatal, statusCode: 502),
      '504': _blameEntry(level: LayerXLogLevel.error, statusCode: 504),
      'network': _blameEntry(
          level: LayerXLogLevel.error,
          source: LayerXLogSource.network,
          message: 'Failed host lookup'),
      'timeout': _blameEntry(level: LayerXLogLevel.error, statusCode: 408),
      '429': _blameEntry(level: LayerXLogLevel.warning, statusCode: 429),
      '401': _blameEntry(level: LayerXLogLevel.error, statusCode: 401),
      '403': _blameEntry(level: LayerXLogLevel.error, statusCode: 403),
      '409': _blameEntry(level: LayerXLogLevel.warning, statusCode: 409),
      '422': _blameEntry(level: LayerXLogLevel.error, statusCode: 422),
      '404': _blameEntry(level: LayerXLogLevel.error, statusCode: 404),
      'parse (model mismatch)': _blameEntry(
          level: LayerXLogLevel.error,
          message: 'FormatException: unexpected character'),
      'parse (contract changed)': _blameEntry(
          level: LayerXLogLevel.error,
          message: 'FormatException while parsing',
          responseChanged: true),
      'flutter/app': _blameEntry(
          level: LayerXLogLevel.error,
          source: LayerXLogSource.app,
          message: 'Null check operator used on a null value'),
      'platform': _blameEntry(
          level: LayerXLogLevel.error,
          source: LayerXLogSource.unknown,
          message: 'PlatformException(camera_unavailable)'),
      'fallback': _blameEntry(
          level: LayerXLogLevel.error,
          source: LayerXLogSource.unknown,
          message: 'undetermined mystery failure'),
    };
    cases.forEach((label, entry) {
      test('$label verdict icon on surface', () {
        final info = LayerXBlameEngine.analyze(entry);
        expect(info, isNotNull,
            reason: '"$label" should produce a blame verdict');
        _expectContrast(info!.color, LxTheme.surface, 3.0, '$label blame');
      });
    });
  });
}
