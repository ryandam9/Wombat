import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Wombat's Soft Modern Material 3 themes.
///
/// Visual language: generous rounding, soft diffused elevation, hairline
/// outlines, calm surfaces, confident-but-friendly typography, and a curated
/// warm Australian palette (clay, eucalyptus, sand, charcoal). Material 3 is the
/// engineering base; the component themes tune it toward a calm, contemporary
/// app feel.
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
    // Neutral, cool-leaning surfaces by default — white cards on a soft grey
    // page — so the app no longer reads as warm/yellow. A user-chosen
    // background tint (Settings → Appearance → Background) still overrides this.
    final panel = background ?? WombatColors.paper;
    final scaffold =
        background == null ? WombatColors.mist : sink(background, 0.045);
    return ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light)
        .copyWith(
      primary: brand,
      onPrimary: _onAccent(brand),
      primaryContainer: brand.withValues(alpha: 0.14),
      onPrimaryContainer: WombatColors.ink,
      secondary: WombatColors.eucalyptus,
      onSecondary: WombatColors.cream,
      secondaryContainer: WombatColors.eucalyptus.withValues(alpha: 0.14),
      onSecondaryContainer: WombatColors.ink,
      tertiary: WombatColors.wombatBrown,
      onTertiary: WombatColors.cream,
      tertiaryContainer: WombatColors.wombatBrown.withValues(alpha: 0.14),
      onTertiaryContainer: WombatColors.ink,
      // Surface ramp: panels/tiles take the chosen tint (or cream by default),
      // the scaffold + elevated surfaces sit a step darker.
      surface: scaffold,
      onSurface: WombatColors.ink,
      // Muted secondary tone, dark enough to clear WCAG AA (≈5:1) on the
      // neutral surfaces.
      onSurfaceVariant: const Color(0xFF5C5F67),
      surfaceContainerLowest: panel,
      surfaceContainerLow: panel,
      surfaceContainer: scaffold,
      surfaceContainerHigh: background == null
          ? const Color(0xFFE9EBEF)
          : sink(background, 0.09),
      surfaceContainerHighest: background == null
          ? const Color(0xFFE1E4E9)
          : sink(background, 0.14),
      // Hairline outlines — soft neutral greys.
      outline: const Color(0xFFD4D7DD),
      outlineVariant: const Color(0xFFE6E8EC),
      shadow: const Color(0xFF3B3F47),
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
      // Charcoal surface ramp — deep and calm. A chosen background tint is
      // blended faintly over the charcoal so it stays dark.
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
      outline: const Color(0xFF3C3C46),
      outlineVariant: const Color(0xFF2C2C34),
      shadow: Colors.black,
      inverseSurface: WombatColors.cream,
      onInverseSurface: WombatColors.ink,
    );
  }

  // ── Component themes ─────────────────────────────────────────────────────

  static ThemeData _compose(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final hairline = scheme.outlineVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
          bottom: BorderSide(color: hairline, width: AppTokens.border),
        ),
      ),
      textTheme: _typography(scheme),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: hairline, width: AppTokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: AppTokens.border,
        space: AppTokens.border,
      ),
      inputDecorationTheme: _inputDecoration(scheme, isDark),
      filledButtonTheme: FilledButtonThemeData(
        style: _softButtonStyle(scheme, filled: true),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _softButtonStyle(scheme, filled: false),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _softButtonStyle(scheme, outlined: true),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          side: BorderSide(color: hairline, width: AppTokens.border),
        ),
        side: BorderSide(color: hairline, width: AppTokens.border),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: hairline, width: AppTokens.border),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return scheme.outline;
        }),
        trackOutlineWidth: WidgetStateProperty.all(AppTokens.border),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: scheme.outlineVariant, width: AppTokens.border),
        ),
      ),
      // A soft tonal segmented control: the selected segment fills with the
      // accent, the rest stay on a low surface.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(
              BorderSide(color: scheme.outline, width: AppTokens.border)),
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
              scheme.primary.withValues(alpha: 0.10)),
          // Keep the default label size so segment text ("System") doesn't wrap
          // in narrow panels.
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerLow),
          elevation: WidgetStateProperty.all(3),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            side: BorderSide(
                color: scheme.outlineVariant, width: AppTokens.border),
          )),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide:
              BorderSide(color: scheme.primary, width: AppTokens.borderThick),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary,
      ),
    ).copyWith(textTheme: _typography(scheme));
  }

  /// A soft, rounded button: gentle elevation (no border) when filled, a
  /// hairline outline when outlined, calm typography throughout.
  static ButtonStyle _softButtonStyle(
    ColorScheme scheme, {
    bool filled = false,
    bool outlined = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
    );
    final bg = filled ? scheme.primary : scheme.surfaceContainerLow;
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
      overlayColor: WidgetStateProperty.all(
        (filled ? scheme.onPrimary : scheme.primary).withValues(alpha: 0.10),
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (!filled) return 0;
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return 1;
        if (states.contains(WidgetState.hovered)) return 3;
        return 2;
      }),
      shadowColor: WidgetStateProperty.all(scheme.shadow),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      side: outlined
          ? WidgetStateProperty.all(
              BorderSide(color: scheme.outline, width: AppTokens.borderInput))
          : null,
    );
  }

  static InputDecorationTheme _inputDecoration(ColorScheme scheme, bool isDark) {
    final border = BorderSide(color: scheme.outline, width: AppTokens.border);
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide:
            BorderSide(color: scheme.primary, width: AppTokens.borderThick),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: scheme.error, width: AppTokens.border),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide:
            BorderSide(color: scheme.error, width: AppTokens.borderThick),
      ),
    );
  }

  /// Confident-but-friendly hierarchy: bold headings, semibold titles, regular
  /// body. Softer than the old all-w800 treatment.
  static TextTheme _typography(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    ).textTheme;
    TextStyle weight(TextStyle? s, FontWeight w) =>
        (s ?? const TextStyle()).copyWith(fontWeight: w);
    return base.copyWith(
      displayLarge: weight(base.displayLarge, FontWeight.w700),
      displayMedium: weight(base.displayMedium, FontWeight.w700),
      displaySmall: weight(base.displaySmall, FontWeight.w700),
      headlineLarge: weight(base.headlineLarge, FontWeight.w700),
      headlineMedium: weight(base.headlineMedium, FontWeight.w700),
      headlineSmall: weight(base.headlineSmall, FontWeight.w700),
      titleLarge: weight(base.titleLarge, FontWeight.w700),
      titleMedium: weight(base.titleMedium, FontWeight.w600),
      titleSmall: weight(base.titleSmall, FontWeight.w600),
      labelLarge: weight(base.labelLarge, FontWeight.w600),
      labelMedium: weight(base.labelMedium, FontWeight.w600),
      labelSmall: weight(base.labelSmall, FontWeight.w600),
    );
  }
}
