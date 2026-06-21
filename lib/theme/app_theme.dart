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

  static ThemeData lightFor(Color seed) =>
      _compose(_lightScheme(seed), Brightness.light);

  static ThemeData darkFor(Color seed) =>
      _compose(_darkScheme(seed), Brightness.dark);

  static ColorScheme _lightScheme(Color seed) {
    final brand = _isDefault(seed) ? WombatColors.clay : seed;
    return ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light)
        .copyWith(
      primary: brand,
      onPrimary: WombatColors.cream,
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
      // Sand/cream surface ramp — warm, high-contrast against ink outlines.
      surface: WombatColors.sand,
      onSurface: WombatColors.ink,
      onSurfaceVariant: const Color(0xFF8A8270),
      surfaceContainerLowest: WombatColors.cream,
      surfaceContainerLow: WombatColors.cream,
      surfaceContainer: WombatColors.sand,
      surfaceContainerHigh: const Color(0xFFEFE8D6),
      surfaceContainerHighest: const Color(0xFFE9E1CD),
      outline: WombatColors.ink,
      outlineVariant: const Color(0xFFB8AE96),
      shadow: WombatColors.ink,
      inverseSurface: WombatColors.ink,
      onInverseSurface: WombatColors.cream,
    );
  }

  static ColorScheme _darkScheme(Color seed) {
    final brand = _isDefault(seed) ? WombatColors.clay : seed;
    return ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark)
        .copyWith(
      primary: brand,
      onPrimary: WombatColors.charcoal,
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
      // Charcoal surface ramp — deep, with bright bone outlines.
      surface: WombatColors.charcoal,
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.surfaceContainerHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor:
            WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: outline, width: AppTokens.border),
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
