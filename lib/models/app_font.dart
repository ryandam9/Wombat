import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Curated font choices for the app. Most are popular Google Fonts (fetched on
/// demand at runtime by `google_fonts`); a few are bundled (Roboto ships with
/// Flutter, the rest with the `auris` package). Intentionally a short, readable
/// list — not the entire Google Fonts catalogue.
enum AppFont {
  system,
  robotoCondensed,
  inter,
  openSans,
  lato,
  notoSans,
  sourceSans3,
  nunito,
  montserrat,
  poppins,
  workSans,
  dmSans,
  ibmPlexSans,
  ptSans,
  oswald,
  barlowCondensed,
  merriweather,
  jetBrainsMono,
  rajdhani,
  exoTwo,
  techMono,
}

extension AppFontX on AppFont {
  /// Human-readable label for the picker.
  String get label => switch (this) {
        AppFont.system => 'System (Roboto)',
        AppFont.robotoCondensed => 'Roboto Condensed',
        AppFont.inter => 'Inter',
        AppFont.openSans => 'Open Sans',
        AppFont.lato => 'Lato',
        AppFont.notoSans => 'Noto Sans',
        AppFont.sourceSans3 => 'Source Sans 3',
        AppFont.nunito => 'Nunito',
        AppFont.montserrat => 'Montserrat',
        AppFont.poppins => 'Poppins',
        AppFont.workSans => 'Work Sans',
        AppFont.dmSans => 'DM Sans',
        AppFont.ibmPlexSans => 'IBM Plex Sans',
        AppFont.ptSans => 'PT Sans',
        AppFont.oswald => 'Oswald',
        AppFont.barlowCondensed => 'Barlow Condensed',
        AppFont.merriweather => 'Merriweather',
        AppFont.jetBrainsMono => 'JetBrains Mono',
        AppFont.rajdhani => 'Rajdhani',
        AppFont.exoTwo => 'Exo 2',
        AppFont.techMono => 'Share Tech Mono',
      };

  /// The Google Fonts text style (via the generated, lookup-free methods),
  /// when this is a Google font. Calling these registers/loads the family.
  TextStyle? get _googleStyle => switch (this) {
        AppFont.inter => GoogleFonts.inter(),
        AppFont.openSans => GoogleFonts.openSans(),
        AppFont.lato => GoogleFonts.lato(),
        AppFont.notoSans => GoogleFonts.notoSans(),
        AppFont.sourceSans3 => GoogleFonts.sourceSans3(),
        AppFont.nunito => GoogleFonts.nunito(),
        AppFont.montserrat => GoogleFonts.montserrat(),
        AppFont.poppins => GoogleFonts.poppins(),
        AppFont.workSans => GoogleFonts.workSans(),
        AppFont.dmSans => GoogleFonts.dmSans(),
        AppFont.ibmPlexSans => GoogleFonts.ibmPlexSans(),
        AppFont.ptSans => GoogleFonts.ptSans(),
        AppFont.oswald => GoogleFonts.oswald(),
        AppFont.barlowCondensed => GoogleFonts.barlowCondensed(),
        AppFont.merriweather => GoogleFonts.merriweather(),
        AppFont.jetBrainsMono => GoogleFonts.jetBrainsMono(),
        _ => null,
      };

  /// Bundled/system family name, for the non-Google options.
  String get _localFamily => switch (this) {
        AppFont.robotoCondensed => 'RobotoCondensed',
        AppFont.rajdhani => 'Rajdhani',
        AppFont.exoTwo => 'ExoTwo',
        AppFont.techMono => 'ShareTechMono',
        _ => 'Roboto', // system
      };

  /// The font-family name to apply. For Google fonts this also triggers
  /// `google_fonts` to register/load the family (falling back gracefully if
  /// offline) — without the name lookup that `getFont` throws on.
  String get family => _googleStyle?.fontFamily ?? _localFamily;

  static AppFont fromIndex(int? index) {
    if (index == null || index < 0 || index >= AppFont.values.length) {
      return AppFont.system;
    }
    return AppFont.values[index];
  }
}
