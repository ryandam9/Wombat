import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? _apiKey;
  String _defaultModel = 'openai/gpt-4o-mini';
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  bool get loading => _loading;
  String? get apiKey => _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String get defaultModel => _defaultModel;
  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    try {
      _apiKey = await _secureStorage.readApiKey();
    } catch (_) {
      _apiKey = null;
    }
    _defaultModel = _prefs.getString(_kDefaultModel) ?? _defaultModel;
    final themeIndex = _prefs.getInt(_kThemeMode);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    _loading = false;
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

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }
}
