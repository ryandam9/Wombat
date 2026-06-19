import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_font.dart';
import '../services/secure_storage_service.dart';

/// Holds user settings: the API key, the default model for new chats, and the
/// app theme mode. The API key lives in secure storage; the rest in prefs.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._secureStorage, this._prefs) {
    _load();
  }

  final SecureStorageService _secureStorage;
  final SharedPreferences _prefs;

  static const _kDefaultModel = 'default_model';
  static const _kThemeMode = 'theme_mode';
  static const _kDownloadDir = 'download_dir';
  static const _kAnimateModelIndicator = 'animate_model_indicator';
  static const _kHeadingFont = 'font_heading';
  static const _kUserFont = 'font_user';
  static const _kModelFont = 'font_model';
  static const _kSettingsFont = 'font_settings';

  String? _apiKey;
  String _defaultModel = 'openai/gpt-4o-mini';
  ThemeMode _themeMode = ThemeMode.system;
  String? _downloadDir;
  bool _animateModelIndicator = false;
  AppFont _headingFont = AppFont.system;
  AppFont _userFont = AppFont.system;
  AppFont _modelFont = AppFont.system;
  AppFont _settingsFont = AppFont.system;
  bool _loading = true;

  bool get loading => _loading;
  String? get apiKey => _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String get defaultModel => _defaultModel;
  ThemeMode get themeMode => _themeMode;

  /// Whether the model indicator in the chat header pulses while streaming.
  /// Off by default so it doesn't blink distractingly.
  bool get animateModelIndicator => _animateModelIndicator;

  /// Fonts for headings, user text, model output, and the settings screen.
  AppFont get headingFont => _headingFont;
  AppFont get userFont => _userFont;
  AppFont get modelFont => _modelFont;
  AppFont get settingsFont => _settingsFont;

  /// Default directory new downloads are written to (desktop). When null, a
  /// Save-As dialog is shown instead.
  String? get downloadDir => _downloadDir;

  Future<void> _load() async {
    try {
      _apiKey = await _secureStorage.readApiKey();
    } catch (_) {
      _apiKey = null;
    }
    _defaultModel = _prefs.getString(_kDefaultModel) ?? _defaultModel;
    _downloadDir = _prefs.getString(_kDownloadDir);
    _animateModelIndicator =
        _prefs.getBool(_kAnimateModelIndicator) ?? false;
    _headingFont =
        AppFontX.fromIndex(_prefs.getInt(_kHeadingFont));
    _userFont = AppFontX.fromIndex(_prefs.getInt(_kUserFont));
    _modelFont = AppFontX.fromIndex(_prefs.getInt(_kModelFont));
    _settingsFont = AppFontX.fromIndex(_prefs.getInt(_kSettingsFont));
    final themeIndex = _prefs.getInt(_kThemeMode);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setDownloadDir(String? dir) async {
    _downloadDir = (dir != null && dir.isNotEmpty) ? dir : null;
    if (_downloadDir != null) {
      await _prefs.setString(_kDownloadDir, _downloadDir!);
    } else {
      await _prefs.remove(_kDownloadDir);
    }
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    if (hasApiKey) {
      await _secureStorage.writeApiKey(_apiKey!);
    } else {
      await _secureStorage.deleteApiKey();
    }
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    await _secureStorage.deleteApiKey();
    notifyListeners();
  }

  Future<void> setDefaultModel(String model) async {
    _defaultModel = model;
    await _prefs.setString(_kDefaultModel, model);
    notifyListeners();
  }

  Future<void> setAnimateModelIndicator(bool value) async {
    _animateModelIndicator = value;
    await _prefs.setBool(_kAnimateModelIndicator, value);
    notifyListeners();
  }

  Future<void> setHeadingFont(AppFont f) async {
    _headingFont = f;
    await _prefs.setInt(_kHeadingFont, f.index);
    notifyListeners();
  }

  Future<void> setUserFont(AppFont f) async {
    _userFont = f;
    await _prefs.setInt(_kUserFont, f.index);
    notifyListeners();
  }

  Future<void> setModelFont(AppFont f) async {
    _modelFont = f;
    await _prefs.setInt(_kModelFont, f.index);
    notifyListeners();
  }

  Future<void> setSettingsFont(AppFont f) async {
    _settingsFont = f;
    await _prefs.setInt(_kSettingsFont, f.index);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }
}
