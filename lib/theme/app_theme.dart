import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Wombat's Neo Brutalist Material 3 themes.
///
/// Visual language: thick dark outlines, hard offset shadows (no blur), flat
/// colour blocks, bold typography, and a curated Australian palette (clay,
/// eucalyptus, sand, charcoal). Material 3 remains the engineering base, but
/// the component themes push it firmly into Neo Brutalist territory.
///
/// Both light and dark themes are built from the same accent ([seed]). The
/// default seed is [WombatColors.clay]; a user-chosen accent re-tints the
/// primary family while the sand/charcoal surfaces stay put.
class AppTheme {
  AppTheme._();

  static const Color defaultSeed = WombatColors.defaultSeed;

  static ThemeData get light => lightFor(defaultSeed);
  static ThemeData get dark => darkFor(defaultSeed);

  static bool _isDefault(Color seed) =>
      seed.toARGB32() == defaultSeed.toARGB32();

  /// Foreground colour (ink or cream) that stays legible on [bg]. Used so a
  /// custom accent of any lightness keeps `onPrimary` readable rather than a
  /// fixed cream/charcoal that fails on very light or awkward accents.
  static Color _onAccent(Color bg) =>
      bg.computeLuminance() > 0.5 ? WombatColors.ink : WombatColors.cream;

  static ThemeData lightFor(Color seed, {Color? background}) =>
      _compose(_lightScheme(seed, background), Brightness.light);

  static ThemeData darkFor(Color seed, {Color? background}) =>
      _compose(_darkScheme(seed, background), Brightness.dark);

  static ColorScheme _lightScheme(Color seed, [Color? background]) {
    final brand = _isDefault(seed) ? WombatColors.clay : seed;
    // A chosen background tint becomes the panel/tile colour; the scaffold and
    // elevated surfaces are derived a touch darker so the warm default's gentle
    // depth is preserved for any tint (a neutral white included). When no tint
    // is set the original warm sand/cream ramp is used unchanged.
    Color sink(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;
    final panel = background ?? WombatColors.cream;
    final scaffold =
        background == null ? WombatColors.sand : sink(background, 0.045);
    return ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light)
        .copyWith(
      primary: brand,
      onPrimary: _onAccent(brand),
      primaryContainer: brand.withValues(alpha: 0.18),
      onPrimaryContainer: WombatColors.ink,
      secondary: WombatColors.eucalyptus,
      onSecondary: WombatColors.cream,
      secondaryContainer: WombatColors.eucalyptus.withValues(alpha: 0.18),
      onSecondaryContainer: WombatColors.ink,
      tertiary: WombatColors.wombatBrown,
      onTertiary: WombatColors.cream,
      tertiaryContainer: WombatColors.wombatBrown.withValues(alpha: 0.18),
      onTertiaryContainer: WombatColors.ink,
      // Surface ramp: panels/tiles take the chosen tint (or cream by default),
      // the scaffold + elevated surfaces sit a step darker.
      surface: scaffold,
      onSurface: WombatColors.ink,
      // Muted secondary tone, darkened to clear WCAG AA (≈5:1) on the cream/sand
      // surfaces — the old #8A8270 only reached ~3.5:1 and read as faint.
      onSurfaceVariant: const Color(0xFF6E6856),
      surfaceContainerLowest: panel,
      surfaceContainerLow: panel,
      surfaceContainer: scaffold,
      surfaceContainerHigh: background == null
          ? const Color(0xFFEFE8D6)
          : sink(background, 0.09),
      surfaceContainerHighest: background == null
          ? const Color(0xFFE9E1CD)
          : sink(background, 0.14),
      outline: WombatColors.ink,
      outlineVariant: const Color(0xFFB8AE96),
      shadow: WombatColors.ink,
      inverseSurface: WombatColors.ink,
      onInverseSurface: WombatColors.cream,
    );
  }

  static ColorScheme _darkScheme(Color seed, [Color? background]) {
    final brand = _isDefault(seed) ? WombatColors.clay : seed;
    return ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark)
        .copyWith(
      primary: brand,
      onPrimary: _onAccent(brand),
      primaryContainer: brand.withValues(alpha: 0.22),
      onPrimaryContainer: WombatColors.cream,
      secondary: WombatColors.eucalyptus,
      onSecondary: WombatColors.charcoal,
      secondaryContainer: WombatColors.eucalyptus.withValues(alpha: 0.22),
      onSecondaryContainer: WombatColors.cream,
      tertiary: WombatColors.skyBlue,
      onTertiary: WombatColors.charcoal,
      tertiaryContainer: WombatColors.skyBlue.withValues(alpha: 0.20),
      onTertiaryContainer: WombatColors.cream,
      // Charcoal surface ramp — deep, with bright bone outlines. A chosen
      // background tint is blended faintly over the charcoal so it stays dark.
      surface: background == null
          ? WombatColors.charcoal
          : Color.alphaBlend(
              background.withValues(alpha: 0.06), WombatColors.charcoal),
      onSurface: WombatColors.cream,
      onSurfaceVariant: const Color(0xFFC9C3B4),
      surfaceContainerLowest: const Color(0xFF16161C),
      surfaceContainerLow: const Color(0xFF22222A),
      surfaceContainer: WombatColors.charcoalPanel,
      surfaceContainerHigh: const Color(0xFF2E2E38),
      surfaceContainerHighest: const Color(0xFF36363F),
      outline: WombatColors.bone,
      outlineVariant: const Color(0xFF54545E),
      shadow: Colors.black,
      inverseSurface: WombatColors.cream,
      onInverseSurface: WombatColors.ink,
    );
  }

  // ── Component themes ─────────────────────────────────────────────────────

  static ThemeData _compose(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final outline = scheme.outline;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: NoSplash.splashFactory, // hard edges, no ink bleed
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        shape: Border(
          bottom: BorderSide(color: outline, width: AppTokens.border),
        ),
      ),
      textTheme: _typography(scheme),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: outline, width: AppTokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: AppTokens.border,
        space: AppTokens.border,
      ),
      inputDecorationTheme: _inputDecoration(scheme, isDark),
      filledButtonTheme: FilledButtonThemeData(
        style: _neoButtonStyle(scheme, filled: true),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _neoButtonStyle(scheme, filled: false),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _neoButtonStyle(scheme, outlined: true),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: outline, width: AppTokens.border),
        ),
        side: BorderSide(color: outline, width: AppTokens.border),
        // An explicit label colour: without one, unselected chip labels fell
        // back to a near-invisible default (filter chips, debug event-stream).
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: outline, width: AppTokens.borderThick),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: outline, width: AppTokens.border),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: outline, width: AppTokens.border),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: outline, width: AppTokens.borderThick),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: outline, width: AppTokens.border),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.zero,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        // A thick outline + a contrasting thumb so the control always reads as
        // a toggle (the old off-state was a faint light pill with a near-
        // invisible light thumb), and the on/off state is obvious.
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline; // dark knob on the light off-track
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(outline),
        trackOutlineWidth: WidgetStateProperty.all(AppTokens.border),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: outline, width: AppTokens.borderThick),
        ),
      ),
      // Chunky bordered segmented control: a flat primary block marks the
      // selection instead of the soft Material pill.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(
              BorderSide(color: outline, width: AppTokens.border)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          )),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.surfaceContainerLow),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.onPrimary
                  : scheme.onSurface),
          overlayColor: WidgetStateProperty.all(
              scheme.primary.withValues(alpha: 0.12)),
          // Keep the default label size so segment text ("System") doesn't wrap
          // in narrow panels; the chunky block + border carry the Neo look.
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 6)),
        ),
      ),
      // A bordered, flat dropdown menu surface to match the panel system.
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          backgroundColor: WidgetStateProperty.all(scheme.surface),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            side: BorderSide(color: outline, width: AppTokens.border),
          )),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: AppTokens.borderThick),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: scheme.primary.withValues(alpha: 0.30),
        cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary,
      ),
    ).copyWith(textTheme: _typography(scheme));
  }

  /// Chunky Neo Brutalist button: thick border, hard offset shadow that lives
  /// behind the button. (The press-compress effect is applied by the widget
  /// wrapping the button — see [PressableScale] / [NeoButton].)
  static ButtonStyle _neoButtonStyle(
    ColorScheme scheme, {
    bool filled = false,
    bool outlined = false,
  }) {
    final border = BorderSide(
      color: scheme.onSurfaceVariant,
      width: AppTokens.border,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      side: border,
    );
    final bg = filled ? scheme.primary : scheme.surface;
    final fg = filled ? scheme.onPrimary : scheme.onSurface;
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 48)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      shape: WidgetStateProperty.all(shape),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.surfaceContainerHighest;
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurfaceVariant;
        }
        return fg;
      }),
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      side: outlined ? WidgetStateProperty.all(border) : null,
    );
  }

  static InputDecorationTheme _inputDecoration(ColorScheme scheme, bool isDark) {
    final border = BorderSide(color: scheme.outline, width: AppTokens.border);
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        borderSide: border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        borderSide: border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        borderSide: BorderSide(color: scheme.primary, width: AppTokens.borderThick),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        borderSide: BorderSide(color: scheme.error, width: AppTokens.border),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        borderSide: BorderSide(color: scheme.error, width: AppTokens.borderThick),
      ),
    );
  }

  /// Bold display/headline weights and tight tracking for a confident hierarchy.
  static TextTheme _typography(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    ).textTheme;
    TextStyle heavy(TextStyle? s, {FontWeight w = FontWeight.w800}) =>
        (s ?? const TextStyle()).copyWith(fontWeight: w);
    return base.copyWith(
      displayLarge: heavy(base.displayLarge),
      displayMedium: heavy(base.displayMedium),
      displaySmall: heavy(base.displaySmall),
      headlineLarge: heavy(base.headlineLarge),
      headlineMedium: heavy(base.headlineMedium),
      headlineSmall: heavy(base.headlineSmall),
      titleLarge: heavy(base.titleLarge),
      titleMedium: heavy(base.titleMedium, w: FontWeight.w700),
      titleSmall: heavy(base.titleSmall, w: FontWeight.w700),
      labelLarge: heavy(base.labelLarge, w: FontWeight.w700),
      labelMedium: heavy(base.labelMedium, w: FontWeight.w700),
      labelSmall: heavy(base.labelSmall, w: FontWeight.w700),
    );
  }
}
