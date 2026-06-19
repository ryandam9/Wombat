import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/app_font.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted api key, model and theme', () async {
    SharedPreferences.setMockInitialValues({
      'default_model': 'anthropic/claude',
      'theme_mode': ThemeMode.dark.index,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(
      FakeSecureStorageService(initial: 'stored-key'),
      prefs,
    );

    await waitUntil(() => !settings.loading);

    expect(settings.apiKey, 'stored-key');
    expect(settings.hasApiKey, isTrue);
    expect(settings.defaultModel, 'anthropic/claude');
    expect(settings.themeMode, ThemeMode.dark);
  });

  test('uses defaults when nothing is persisted', () async {
    final settings = await buildLoadedSettings(apiKey: null);
    expect(settings.hasApiKey, isFalse);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('setApiKey stores and clears the key', () async {
    final settings = await buildLoadedSettings(apiKey: null);

    await settings.setApiKey('  new-key  ');
    expect(settings.apiKey, 'new-key'); // trimmed
    expect(settings.hasApiKey, isTrue);

    await settings.setApiKey('');
    expect(settings.hasApiKey, isFalse);
  });

  test('clearApiKey removes the key', () async {
    final settings = await buildLoadedSettings(apiKey: 'k');
    await settings.clearApiKey();
    expect(settings.apiKey, isNull);
    expect(settings.hasApiKey, isFalse);
  });

  test('setDefaultModel and setThemeMode persist to prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings =
        SettingsProvider(FakeSecureStorageService(), prefs);
    await waitUntil(() => !settings.loading);

    await settings.setDefaultModel('google/gemini');
    await settings.setThemeMode(ThemeMode.light);

    expect(settings.defaultModel, 'google/gemini');
    expect(settings.themeMode, ThemeMode.light);
    expect(prefs.getString('default_model'), 'google/gemini');
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
  });

  test('setDownloadDir persists and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(FakeSecureStorageService(), prefs);
    await waitUntil(() => !settings.loading);

    expect(settings.downloadDir, isNull);

    await settings.setDownloadDir('/home/me/Downloads');
    expect(settings.downloadDir, '/home/me/Downloads');
    expect(prefs.getString('download_dir'), '/home/me/Downloads');

    await settings.setDownloadDir(null);
    expect(settings.downloadDir, isNull);
    expect(prefs.getString('download_dir'), isNull);
  });

  test('animateModelIndicator defaults to false and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(FakeSecureStorageService(), prefs);
    await waitUntil(() => !settings.loading);

    expect(settings.animateModelIndicator, isFalse);
    await settings.setAnimateModelIndicator(true);
    expect(settings.animateModelIndicator, isTrue);
    expect(prefs.getBool('animate_model_indicator'), isTrue);
  });

  test('font settings default sensibly and persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(FakeSecureStorageService(), prefs);
    await waitUntil(() => !settings.loading);

    // All fonts default to Roboto Condensed (the app's default font).
    expect(settings.headingFont, AppFont.robotoCondensed);
    expect(settings.userFont, AppFont.robotoCondensed);
    expect(settings.modelFont, AppFont.robotoCondensed);
    expect(settings.settingsFont, AppFont.robotoCondensed);

    await settings.setModelFont(AppFont.inter);
    expect(settings.modelFont, AppFont.inter);
    expect(prefs.getInt('font_model'), AppFont.inter.index);
  });

  test('notifies listeners on change', () async {
    final settings = await buildLoadedSettings(apiKey: null);
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setThemeMode(ThemeMode.dark);
    expect(notified, greaterThan(0));
  });
}
