// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

/// Central design-token file for the LayerX Debugger in-app viewer.
/// All widgets import from here — single source of truth.
///
/// Visual language: **Neo Terminal** — a pure-black devtools console with a
/// neon-green primary accent, a cyan secondary, hairline green-tinted borders
/// and monospace-forward typography.
abstract final class LxTheme {
  // ── Background layers ──────────────────────────────────────────────────────
  static const bg = Color(0xFF03060A);
  static const surface = Color(0xFF080D0A);
  static const surfaceAlt = Color(0xFF0B120E);
  static const surfaceHigh = Color(0xFF0F1D15);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const border = Color(0xFF12301E);
  static const borderActive = Color(0xFF1E5836);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFDFFBE6);
  static const textSecondary = Color(0xFF6FA982);
  static const textDim = Color(0xFF38573F);

  // ── Accent palette (used for methods, levels, sources) ─────────────────────
  static const accentBlue = Color(0xFF38BDF8);
  static const accentPurple = Color(0xFFA78BFA);
  static const accentGreen = Color(0xFF3FE06B);
  static const accentAmber = Color(0xFFE3B341);
  static const accentRed = Color(0xFFFF5C57);
  static const accentCyan = Color(0xFF22D3EE);
  static const accentOrange = Color(0xFFFF9F45);

  // ── Brand accent ───────────────────────────────────────────────────────────
  // The primary brand color of the Neo Terminal viewer: neon green, paired with
  // a near-white green ink for active states.
  static const accent = Color(0xFF39D353);
  static const accentInk = Color(0xFFEAFFEF);

  // ── Glow helpers ───────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double spread = 6}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: spread * 2,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: spread * 4,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: Color(0x66000000),
      blurRadius: 14,
      offset: Offset(0, 5),
    ),
  ];

  // ── Card decoration ────────────────────────────────────────────────────────
  static BoxDecoration card({Color? glowColor}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: glowColor != null ? glowShadow(glowColor) : cardShadow,
      );

  static BoxDecoration cardAlt({Color? glowColor}) => BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderActive),
        boxShadow: glowColor != null ? glowShadow(glowColor) : cardShadow,
      );

  // ── Typography ─────────────────────────────────────────────────────────────
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 1.6,
    fontFamily: 'monospace',
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle monoSm = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle bodyPrimary = TextStyle(
    fontSize: 13,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 12,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle labelBold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  // ── Badge / pill ───────────────────────────────────────────────────────────
  static BoxDecoration pill(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      );

  static BoxDecoration pillSolid(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      );

  // ── Divider ────────────────────────────────────────────────────────────────
  static const Divider divider = Divider(
    color: border,
    height: 1,
    thickness: 1,
  );

  // ── AppBar theme ───────────────────────────────────────────────────────────
  static AppBarTheme get appBarTheme => const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontFamily: 'monospace',
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
        actionsIconTheme: IconThemeData(color: textSecondary, size: 20),
      );

  // ── Snackbar ───────────────────────────────────────────────────────────────
  static SnackBar snackBar(String message) => SnackBar(
        content: Text(message, style: monoSm.copyWith(color: accentInk)),
        backgroundColor: surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderActive),
        ),
        duration: const Duration(seconds: 2),
      );
}
