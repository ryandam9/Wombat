import 'package:flutter/material.dart';

/// Wombat's Neo Brutalist design tokens.
///
/// One controlled source of truth for the bold, chunky visual language: border
/// weights, radii, hard offset shadows, padding, and the curated Australian
/// palette. Widgets should read these rather than inventing ad-hoc values so
/// the whole app stays consistent.
class AppTokens {
  AppTokens._();

  // ── Borders ──────────────────────────────────────────────────────────────
  static const double border = 2.0; // default card/panel outline
  static const double borderThick = 3.0; // emphasis (selected, headers)
  static const double borderInput = 2.0;

  // ── Radii ────────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  // ── Hard offset shadows (Neo Brutalist signature) ────────────────────────
  // A flat coloured offset, not a soft blur. The shadow sits behind+right.
  static const Offset shadowSm = Offset(2, 2);
  static const Offset shadowMd = Offset(4, 4);
  static const Offset shadowLg = Offset(6, 6);
  static const double shadowBlur = 0; // hard edge, no blur

  // ── Padding ──────────────────────────────────────────────────────────────
  static const double padCard = 16;
  static const double padPanel = 20;

  // ── Animation durations ──────────────────────────────────────────────────
  static const Duration durFast = Duration(milliseconds: 140);
  static const Duration durMed = Duration(milliseconds: 250);
  static const Duration durSlow = Duration(milliseconds: 380);

  // ── Signature motion curves ───────────────────────────────────────────────
  // A little overshoot gives the playful Neo Brutalist "snap into place" bounce.
  static const Curve curveOvershoot = Curves.easeOutBack;
  static const Curve curveSnap = Curves.easeOutCubic;

  // ── Hover lift (desktop/web) ───────────────────────────────────────────────
  // On hover a card rises: its hard shadow grows and the card nudges up-left.
  static const Offset hoverLift = Offset(-1, -1); // translation on hover
  static const double hoverShadowGrow = 2; // extra px added to the shadow offset

}

/// The curated Wombat palette: Australian nature, bolder. These are the raw
/// accent values; the light/dark [ColorScheme]s in `app_theme.dart` derive
/// surfaces and on-colours from them.
class WombatColors {
  WombatColors._();

  // ── Core surfaces ────────────────────────────────────────────────────────
  static const Color sand = Color(0xFFF5EFE0); // light scaffold / cards
  static const Color cream = Color(0xFFFBF7EC); // lightest surface
  static const Color charcoal = Color(0xFF1E1E24); // dark scaffold
  static const Color charcoalPanel = Color(0xFF26262E); // dark card
  static const Color ink = Color(0xFF16161C); // outlines in light theme
  static const Color bone = Color(0xFFE9E2D0); // outlines in dark theme

  // ── Brand / nature ───────────────────────────────────────────────────────
  static const Color clay = Color(0xFFC75D3A); // warm clay — primary
  static const Color eucalyptus = Color(0xFF4A8B5C); // green — secondary
  static const Color wombatBrown = Color(0xFF8B6F47); // brown — tertiary
  static const Color skyBlue = Color(0xFF4FB3E8); // sky
  static const Color gumBlue = Color(0xFF6B8A9E); // muted blue-grey

  // ── Playful accents (used sparingly for blocks/badges) ───────────────────
  static const Color coral = Color(0xFFE85D5D);
  static const Color yellow = Color(0xFFF2C94C);
  static const Color mint = Color(0xFF6FCF97);
  static const Color lavender = Color(0xFFB5A8E0);

  /// The default Neo Brutalist seed (clay) used when the user hasn't picked a
  /// custom accent.
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
