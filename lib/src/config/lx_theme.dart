// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

/// Central design-token file for the LayerX Debugger in-app viewer.
/// All widgets import from here — single source of truth.
abstract final class LxTheme {
  // ── Background layers ──────────────────────────────────────────────────────
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF111318);
  static const surfaceAlt = Color(0xFF161B22);
  static const surfaceHigh = Color(0xFF1C2128);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const border = Color(0xFF21262D);
  static const borderActive = Color(0xFF30363D);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textDim = Color(0xFF484F58);

  // ── Accent palette ─────────────────────────────────────────────────────────
  static const accentBlue = Color(0xFF58A6FF);
  static const accentPurple = Color(0xFFBC8CFF);
  static const accentGreen = Color(0xFF3FB950);
  static const accentAmber = Color(0xFFD29922);
  static const accentRed = Color(0xFFF85149);
  static const accentCyan = Color(0xFF39D353);
  static const accentOrange = Color(0xFFF0883E);

  // ── Glow helpers ───────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double spread = 6}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: spread * 2,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: spread * 4,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
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
    letterSpacing: 1.5,
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
        actionsIconTheme: IconThemeData(color: textSecondary, size: 20),
      );

  // ── Snackbar ───────────────────────────────────────────────────────────────
  static SnackBar snackBar(String message) => SnackBar(
        content: Text(message, style: bodySecondary.copyWith(color: textPrimary)),
        backgroundColor: surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderActive),
        ),
        duration: const Duration(seconds: 2),
      );
}
