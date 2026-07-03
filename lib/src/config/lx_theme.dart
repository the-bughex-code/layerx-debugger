// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

/// Central design-token file for the LayerX Debugger in-app viewer.
/// All widgets import from here — single source of truth.
///
/// Visual language: **LayerX DS 2026** (UX spec §4, dark-neutral identity) —
/// a calm neutral surface ramp where every load-bearing text token meets
/// WCAG AA (≥ 4.5:1, enforced by `test/config/theme_contrast_test.dart`),
/// one considered brand green, a semantic accent set, and crash/fatal red as
/// the most prominent color in the system. Monospace is reserved for actual
/// code (payloads, stack traces, endpoints); everything a tester reads is a
/// humanist sans.
abstract final class LxTheme {
  // ── Background layers (§4.2.2 neutral ramp) ────────────────────────────────
  // A true neutral ramp with a barely-there cool tint (not green), restoring
  // the layer separation the old #03060A/#080D0A pair lost.
  static const bg = Color(0xFF0B0E12); // app/scaffold background
  static const surface = Color(0xFF151A21); // cards, app bar, sheets, fields
  static const surfaceAlt = Color(0xFF1B222B); // nested surfaces, chips at rest
  static const surfaceHigh = Color(0xFF222B36); // hover / pressed / selected

  // ── Borders ────────────────────────────────────────────────────────────────
  static const border = Color(0xFF2A333F); // default hairline
  // §4.2.2 `borderStrong` — active field, selected control, focus-ring base.
  // Name kept stable (every widget references `borderActive`).
  static const borderActive = Color(0xFF3A4552);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F5F8); // ~15.8:1 on surface
  static const textSecondary = Color(0xFFAEB8C4); // ~7.9:1 on surface

  /// De-emphasized-but-still-legible (~5.1:1 on surface). Replaces the retired
  /// sub-AA `textDim` (#38573F, ~2.4:1); per §4.2.2 there is **no sub-AA text
  /// token** — placeholders and disabled states use this at full opacity.
  static const textTertiary = Color(0xFF8B95A2);

  /// §4.6 deletes `textDim` as a *value*; the name survives as an alias of
  /// [textTertiary] so no existing call site can ever render sub-AA again.
  static const textDim = textTertiary;

  // ── Accent palette (§4.2.4 semantic set — names kept stable) ───────────────
  static const accentBlue = Color(0xFF5AA9FF); // info: neutral network/info
  static const accentGreen = Color(0xFF3DD68C); // success: 2xx, inbox-zero
  static const accentAmber = Color(0xFFF4B740); // warning: slow, shape change
  static const accentRed = Color(0xFFFF6B6B); // danger: recoverable errors

  // §4 retires the purple/cyan/orange hues; their only consumers are method
  // and status colors, which §4.2.4 folds into the semantic set (PUT/PATCH →
  // warning, "other" methods → neutral, changed-shape → warning). The token
  // names stay for call-site stability; values re-point semantically.
  static const accentPurple = accentAmber; // PATCH joins PUT under warning
  static const accentCyan = textSecondary; // "other" methods → neutral
  static const accentOrange = accentAmber; // changed-shape → warning

  // ── Critical (crash / fatal) — §4.2.4 ──────────────────────────────────────
  /// Crash/fatal — the strongest, most prominent color in the system. The
  /// only accent allowed to fill an entire card header band (§4.2.4).
  static const critical = Color(0xFFFF3B3B);

  /// Text/icon ink drawn *on* a critical tint band — ≥4.5:1 both there and on
  /// plain [surface] (§4.2.5 `-on` contract).
  static const criticalOn = Color(0xFFFFB4B4);

  // ── Brand accent ───────────────────────────────────────────────────────────
  // One considered LayerX green (§4.2.4 `brand`): primary actions, "Live",
  // healthy state.
  static const accent = Color(0xFF3DD68C);

  /// Label ink used **on** brand-solid fills (§4.5.5 primary button) —
  /// dark-on-green ≥4.5:1, replacing the old near-white-on-neon pairing.
  static const accentInk = Color(0xFF0B0E12);

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

  /// §4.4 `elev.1` — a subtle physical shadow (0 1 2, 40% black); the visible
  /// hairline border does the separating, the shadow just lifts the card.
  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: Color(0x66000000),
      blurRadius: 2,
      offset: Offset(0, 1),
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

  // ── Typography (§4.3: sans for reading, mono ONLY for code) ────────────────

  /// §4.3 `overline` — sans section labels. Was 1.6-tracked monospace; still
  /// clearly a label, no longer a shouty terminal string.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// §4.3 `code` — JSON payloads and stack traces. [mono] and [monoSm] are
  /// the only monospace styles in the system.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: textPrimary,
    height: 1.55,
  );

  /// §4.3 `codeSm` — endpoint paths, status codes, durations.
  static const TextStyle monoSm = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.4,
  );

  /// §4.3 `body` — verdict lines, descriptions, dialog copy.
  static const TextStyle bodyPrimary = TextStyle(
    fontSize: 15,
    color: textPrimary,
    height: 1.5,
  );

  /// §4.3 `label` — chips, buttons, metadata, subtitles.
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// §4.3 `caption` — timestamps, ×N, meta lines, helper text, placeholders.
  /// Sans, at [textTertiary] (the §4.2.2 successor of the old dim meta color).
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    height: 1.35,
    letterSpacing: 0.2,
  );

  /// §4.3 `bodyStrong` — emphasis within body, primary button labels.
  static const TextStyle labelBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );

  // ── Badge / pill ───────────────────────────────────────────────────────────
  // §4.5 pills: `radius.sm` (8) and a clearly visible edge on the tint fill —
  // a chip must read as a bounded control, not a faint wash.
  static BoxDecoration pill(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      );

  static BoxDecoration pillSolid(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
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
        // §4.3 `titleM` — sans app-bar title (monospace retired here).
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
        actionsIconTheme: IconThemeData(color: textSecondary, size: 20),
      );

  // ── Snackbar ───────────────────────────────────────────────────────────────
  static SnackBar snackBar(String message) => SnackBar(
        // §4.5.10 — sans body text in textPrimary on surfaceHigh.
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
