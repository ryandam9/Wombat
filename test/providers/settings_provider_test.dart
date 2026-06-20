import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/app_font.dart';
import 'package:wombat/providers/app_providers.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/theme/app_theme.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted api key, model and theme', () async {
    final c = await createContainer(
      apiKey: 'stored-key',
      prefs: {
        'default_model': 'anthropic/claude',
        'theme_mode': ThemeMode.dark.index,
      },
    );
    addTearDown(c.dispose);

    final s = c.read(settingsProvider);
    expect(s.apiKey, 'stored-key');
    expect(s.hasApiKey, isTrue);
    expect(s.defaultModel, 'anthropic/claude');
    expect(s.themeMode, ThemeMode.dark);
  });

  test('uses defaults when nothing is persisted', () async {
    final c = await createContainer(apiKey: null, prefs: const {});
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.hasApiKey, isFalse);
    expect(s.themeMode, ThemeMode.system);
  });

  test('setApiKey stores and clears the key', () async {
    final c = await createContainer(apiKey: null);
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    await n.setApiKey('  new-key  ');
    expect(c.read(settingsProvider).apiKey, 'new-key'); // trimmed
    expect(c.read(settingsProvider).hasApiKey, isTrue);

    await n.setApiKey('');
    expect(c.read(settingsProvider).hasApiKey, isFalse);
  });

  test('clearApiKey removes the key', () async {
    final c = await createContainer(apiKey: 'k');
    addTearDown(c.dispose);
    await c.read(settingsProvider.notifier).clearApiKey();
    expect(c.read(settingsProvider).apiKey, isNull);
    expect(c.read(settingsProvider).hasApiKey, isFalse);
  });

  test('seeds the API key from the environment when none is stored', () async {
    final c = await createContainer(
      apiKey: null,
      environment: const {'OPENROUTER_API_KEY': '  env-key  '},
    );
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.apiKey, 'env-key'); // trimmed
    expect(s.hasApiKey, isTrue);
    expect(s.apiKeyFromEnvironment, isTrue);
    expect(s.apiKeyEnvVarName, 'OPENROUTER_API_KEY');
  });

  test('a stored API key takes precedence over the environment', () async {
    final c = await createContainer(
      apiKey: 'stored-key',
      environment: const {'OPENROUTER_API_KEY': 'env-key'},
    );
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.apiKey, 'stored-key');
    expect(s.apiKeyFromEnvironment, isFalse);
  });

  test('saving overrides the environment key; clearing reverts to it',
      () async {
    final c = await createContainer(
      apiKey: null,
      environment: const {'OPENROUTER_API_KEY': 'env-key'},
    );
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    expect(c.read(settingsProvider).apiKeyFromEnvironment, isTrue);

    await n.setApiKey('manual-key');
    expect(c.read(settingsProvider).apiKey, 'manual-key');
    expect(c.read(settingsProvider).apiKeyFromEnvironment, isFalse);

    await n.clearApiKey();
    expect(c.read(settingsProvider).apiKey, 'env-key');
    expect(c.read(settingsProvider).apiKeyFromEnvironment, isTrue);
  });

  test('setDefaultModel and setThemeMode persist to prefs', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    await n.setDefaultModel('google/gemini');
    await n.setThemeMode(ThemeMode.light);

    final s = c.read(settingsProvider);
    expect(s.defaultModel, 'google/gemini');
    expect(s.themeMode, ThemeMode.light);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString('default_model'), 'google/gemini');
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
  });

  test('setDownloadDir persists and clears', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    final prefs = c.read(sharedPreferencesProvider);

    expect(c.read(settingsProvider).downloadDir, isNull);

    await n.setDownloadDir('/home/me/Downloads');
    expect(c.read(settingsProvider).downloadDir, '/home/me/Downloads');
    expect(prefs.getString('download_dir'), '/home/me/Downloads');

    await n.setDownloadDir(null);
    expect(c.read(settingsProvider).downloadDir, isNull);
    expect(prefs.getString('download_dir'), isNull);
  });

  test('animateModelIndicator defaults to false and persists', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).animateModelIndicator, isFalse);
    await n.setAnimateModelIndicator(true);
    expect(c.read(settingsProvider).animateModelIndicator, isTrue);
    expect(c.read(sharedPreferencesProvider).getBool('animate_model_indicator'),
        isTrue);
  });

  test('monoFont defaults to JetBrains Mono and persists', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).monoFont, AppFont.jetBrainsMono);
    expect(c.read(settingsProvider).monoFont.isMonospace, isTrue);
    await n.setMonoFont(AppFont.firaCode);
    expect(c.read(settingsProvider).monoFont, AppFont.firaCode);
    expect(c.read(sharedPreferencesProvider).getInt('font_mono'),
        AppFont.firaCode.index);
  });

  test('continuousModelBorder defaults to false and persists', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).continuousModelBorder, isFalse);
    await n.setContinuousModelBorder(true);
    expect(c.read(settingsProvider).continuousModelBorder, isTrue);
    expect(c.read(sharedPreferencesProvider).getBool('continuous_model_border'),
        isTrue);
  });

  test('font settings default sensibly and persist', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    // All fonts default to Roboto Condensed (the app's default font).
    final s = c.read(settingsProvider);
    expect(s.headingFont, AppFont.robotoCondensed);
    expect(s.userFont, AppFont.robotoCondensed);
    expect(s.modelFont, AppFont.robotoCondensed);
    expect(s.settingsFont, AppFont.robotoCondensed);

    await n.setModelFont(AppFont.inter);
    expect(c.read(settingsProvider).modelFont, AppFont.inter);
    expect(c.read(sharedPreferencesProvider).getInt('font_model'),
        AppFont.inter.index);
  });

  test('font scales default to 1.0, persist and clamp', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    final prefs = c.read(sharedPreferencesProvider);

    expect(c.read(settingsProvider).userFontScale, 1.0);
    expect(c.read(settingsProvider).modelFontScale, 1.0);

    await n.setUserFontScale(1.3);
    await n.setModelFontScale(1.15);
    expect(c.read(settingsProvider).userFontScale, 1.3);
    expect(c.read(settingsProvider).modelFontScale, 1.15);
    expect(prefs.getDouble('font_scale_user'), 1.3);
    expect(prefs.getDouble('font_scale_model'), 1.15);

    // Out-of-range values are clamped to the allowed bounds.
    await n.setUserFontScale(99);
    expect(c.read(settingsProvider).userFontScale,
        SettingsNotifier.maxFontScale);
    await n.setUserFontScale(0.1);
    expect(c.read(settingsProvider).userFontScale,
        SettingsNotifier.minFontScale);
  });

  test('favorite models persist and toggle', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    final prefs = c.read(sharedPreferencesProvider);

    expect(c.read(settingsProvider).favoriteModels, isEmpty);

    await n.toggleFavoriteModel('openai/gpt-4o');
    expect(c.read(settingsProvider).isFavoriteModel('openai/gpt-4o'), isTrue);
    expect(prefs.getStringList('favorite_models'), contains('openai/gpt-4o'));

    await n.toggleFavoriteModel('openai/gpt-4o');
    expect(c.read(settingsProvider).isFavoriteModel('openai/gpt-4o'), isFalse);
    expect(prefs.getStringList('favorite_models'),
        isNot(contains('openai/gpt-4o')));
  });

  test('seedColor defaults to the brand colour and persists', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).seedColor, AppTheme.defaultSeed);

    const custom = Color(0xFF0D9488);
    await n.setSeedColor(custom);
    expect(c.read(settingsProvider).seedColor, custom);
    expect(c.read(sharedPreferencesProvider).getInt('seed_color'),
        custom.toARGB32());
  });

  test('notifies listeners on change', () async {
    final c = await createContainer(apiKey: null);
    addTearDown(c.dispose);
    var notified = 0;
    c.listen(settingsProvider, (_, __) => notified++);
    await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    expect(notified, greaterThan(0));
  });

  test('reduceMotion defaults off and persists', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).reduceMotion, isFalse);
    await n.setReduceMotion(true);
    expect(c.read(settingsProvider).reduceMotion, isTrue);
    expect(c.read(sharedPreferencesProvider).getBool('reduce_motion'), isTrue);
  });

  test('sidebarWidth defaults and persists clamped', () async {
    final c = await createContainer(prefs: const {});
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);

    expect(c.read(settingsProvider).sidebarWidth,
        SettingsNotifier.defaultSidebarWidth);

    // Out-of-range values are clamped to the allowed bounds.
    await n.setSidebarWidth(9999);
    expect(c.read(settingsProvider).sidebarWidth,
        SettingsNotifier.maxSidebarWidth);
    expect(c.read(sharedPreferencesProvider).getDouble('sidebar_width'),
        SettingsNotifier.maxSidebarWidth);
  });
}
