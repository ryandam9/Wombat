import 'package:flutter/material.dart';

/// Wombat's Soft Modern design tokens.
///
/// One controlled source of truth for the calm, contemporary visual language:
/// generous rounding, soft diffused elevation, hairline outlines, airy padding,
/// gentle motion, and the curated Australian palette. Widgets should read these
/// rather than inventing ad-hoc values so the whole app stays consistent.
class AppTokens {
  AppTokens._();

  // ── Borders ──────────────────────────────────────────────────────────────
  // Hairline outlines that separate surfaces without shouting. Emphasis comes
  // from soft elevation and the accent, not from thick dark strokes.
  static const double border = 1.0; // default card/panel outline
  static const double borderThick = 1.5; // emphasis (selected, focus)
  static const double borderInput = 1.5;

  // ── Radii ────────────────────────────────────────────────────────────────
  // Generous, friendly rounding.
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  // ── Soft elevation ────────────────────────────────────────────────────────
  // The signature of the new look: gentle, blurred shadows that sit directly
  // below an element (no hard offset). [softShadow] is the canonical way to add
  // depth; the [shadow*] offsets below are kept only so existing call-sites that
  // tune a card's lift keep compiling — they map to elevation *levels*.
  static const Offset shadowSm = Offset(0, 2);
  static const Offset shadowMd = Offset(0, 4);
  static const Offset shadowLg = Offset(0, 8);
  static const double shadowBlur = 16; // diffused, never a hard edge

  /// Soft, diffused elevation. Subtle and warm in light, deeper in dark.
  /// [level] 0 (flat) … 3 (lifted). This replaces the old hard offset shadow
  /// everywhere — pass a [ColorScheme] so the shadow tone follows the theme.
  static List<BoxShadow> softShadow(ColorScheme scheme, {int level = 1}) {
    final dark = scheme.brightness == Brightness.dark;
    // A warm-grey cast in light theme keeps shadows from looking cold against
    // the sand/cream surfaces; near-black in dark theme.
    final tint = dark ? const Color(0xFF000000) : const Color(0xFF5C4A2E);
    double a(double light, double darkA) => dark ? darkA : light;
    switch (level) {
      case 0:
        return const <BoxShadow>[];
      case 2:
        return [
          BoxShadow(
              color: tint.withValues(alpha: a(0.10, 0.42)),
              blurRadius: 22,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: tint.withValues(alpha: a(0.06, 0.28)),
              blurRadius: 5,
              offset: const Offset(0, 1)),
        ];
      case 3:
        return [
          BoxShadow(
              color: tint.withValues(alpha: a(0.14, 0.52)),
              blurRadius: 36,
              offset: const Offset(0, 16)),
          BoxShadow(
              color: tint.withValues(alpha: a(0.08, 0.32)),
              blurRadius: 9,
              offset: const Offset(0, 3)),
        ];
      case 1:
      default:
        return [
          BoxShadow(
              color: tint.withValues(alpha: a(0.08, 0.36)),
              blurRadius: 12,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: tint.withValues(alpha: a(0.05, 0.22)),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ];
    }
  }

  // ── Padding ──────────────────────────────────────────────────────────────
  static const double padCard = 18;
  static const double padPanel = 22;

  // ── Animation durations ──────────────────────────────────────────────────
  static const Duration durFast = Duration(milliseconds: 140);
  static const Duration durMed = Duration(milliseconds: 240);
  static const Duration durSlow = Duration(milliseconds: 360);

  // ── Signature motion curves ───────────────────────────────────────────────
  // Calm, decelerating motion — things ease into place rather than snapping or
  // bouncing.
  static const Curve curveOvershoot = Curves.easeOutCubic;
  static const Curve curveSnap = Curves.easeOutCubic;

  // ── Hover lift (desktop/web) ───────────────────────────────────────────────
  // On hover an interactive surface rises a touch and its soft shadow deepens.
  static const Offset hoverLift = Offset(0, -2); // translation on hover
  static const double hoverShadowGrow = 1; // bumps the elevation level on hover
}

/// The curated Wombat palette: Australian nature, warm and grounded. These are
/// the raw accent values; the light/dark [ColorScheme]s in `app_theme.dart`
/// derive surfaces and on-colours from them.
class WombatColors {
  WombatColors._();

  // ── Core surfaces ────────────────────────────────────────────────────────
  static const Color sand = Color(0xFFF5EFE0); // light scaffold
  static const Color cream = Color(0xFFFBF7EC); // lightest surface / cards
  static const Color charcoal = Color(0xFF1E1E24); // dark scaffold
  static const Color charcoalPanel = Color(0xFF26262E); // dark card
  static const Color ink = Color(0xFF16161C); // darkest text
  static const Color bone = Color(0xFFE9E2D0); // lightest text (dark theme)

  // ── Brand / nature ───────────────────────────────────────────────────────
  static const Color clay = Color(0xFFC75D3A); // warm clay — primary
  static const Color eucalyptus = Color(0xFF4A8B5C); // green — secondary
  static const Color wombatBrown = Color(0xFF8B6F47); // brown — tertiary
  static const Color skyBlue = Color(0xFF4FB3E8); // sky
  static const Color gumBlue = Color(0xFF6B8A9E); // muted blue-grey

  // ── Playful accents (used sparingly for badges/banners) ───────────────────
  static const Color coral = Color(0xFFE85D5D);
  static const Color yellow = Color(0xFFF2C94C);
  static const Color mint = Color(0xFF6FCF97);
  static const Color lavender = Color(0xFFB5A8E0);

  /// The default seed (clay) used when the user hasn't picked a custom accent.
  static const Color defaultSeed = clay;
}

/// A version of the accent ([ColorScheme.primary]) guaranteed to read as an
/// outline against the scheme's surface.
///
/// A near-white custom accent would otherwise vanish as a selection border on
/// the light page (and a near-black one in dark theme). When the accent is too
/// close in lightness to the surface, this pushes its lightness away — darker in
/// light theme, lighter in dark theme — while keeping the hue. Normal accents
/// (already distinct from the surface) are returned unchanged, and fills/text
/// keep the raw accent so the user's colour choice is honoured.
Color accentOutline(ColorScheme scheme) {
  final accent = scheme.primary;
  final surfaceLum = scheme.surface.computeLuminance();
  final accentLum = accent.computeLuminance();
  final hi = (surfaceLum > accentLum ? surfaceLum : accentLum) + 0.05;
  final lo = (surfaceLum > accentLum ? accentLum : surfaceLum) + 0.05;
  if (hi / lo >= 1.7) return accent; // already distinct enough from the surface
  final hsl = HSLColor.fromColor(accent);
  final target = scheme.brightness == Brightness.light
      ? (hsl.lightness - 0.4).clamp(0.0, 1.0)
      : (hsl.lightness + 0.4).clamp(0.0, 1.0);
  return hsl.withLightness(target.toDouble()).toColor();
}
