import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layerx_debugger/src/config/lx_theme.dart';

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
}
