import 'package:google_fonts/google_fonts.dart';

/// Curated font choices for the app. Most are popular Google Fonts (fetched on
/// demand at runtime by `google_fonts`); a few are bundled (Roboto ships with
/// Flutter, the rest with the `auris` package). This is intentionally a short,
/// readable list — not the entire Google Fonts catalogue.
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
  ptSans,
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
        AppFont.ptSans => 'PT Sans',
        AppFont.merriweather => 'Merriweather',
        AppFont.jetBrainsMono => 'JetBrains Mono',
        AppFont.rajdhani => 'Rajdhani',
        AppFont.exoTwo => 'Exo 2',
        AppFont.techMono => 'Share Tech Mono',
      };

  /// The Google Fonts family name, when this is a Google font.
  String? get _googleName => switch (this) {
        AppFont.robotoCondensed => 'Roboto Condensed',
        AppFont.inter => 'Inter',
        AppFont.openSans => 'Open Sans',
        AppFont.lato => 'Lato',
        AppFont.notoSans => 'Noto Sans',
        AppFont.sourceSans3 => 'Source Sans 3',
        AppFont.nunito => 'Nunito',
        AppFont.montserrat => 'Montserrat',
        AppFont.poppins => 'Poppins',
        AppFont.ptSans => 'PT Sans',
        AppFont.merriweather => 'Merriweather',
        AppFont.jetBrainsMono => 'JetBrains Mono',
        _ => null,
      };

  /// Bundled/system family name, for the non-Google options.
  String get _localFamily => switch (this) {
        AppFont.rajdhani => 'Rajdhani',
        AppFont.exoTwo => 'ExoTwo',
        AppFont.techMono => 'ShareTechMono',
        _ => 'Roboto', // system
      };

  /// The font-family name to apply. For Google fonts this also triggers
  /// `google_fonts` to register/fetch the family.
  String get family {
    final g = _googleName;
    if (g != null) return GoogleFonts.getFont(g).fontFamily ?? 'Roboto';
    return _localFamily;
  }

  static AppFont fromIndex(int? index) {
    if (index == null || index < 0 || index >= AppFont.values.length) {
      return AppFont.system;
    }
    return AppFont.values[index];
  }
}
