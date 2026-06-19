import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_font.dart';
import '../services/secure_storage_service.dart';
import 'app_providers.dart';

/// Riverpod provider for app settings.
final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// Immutable snapshot of user settings exposed to the UI.
class SettingsState {
  const SettingsState({
    required this.loading,
    required this.apiKey,
    required this.apiKeyFromEnvironment,
    required this.defaultModel,
    required this.themeMode,
    required this.downloadDir,
    required this.animateModelIndicator,
    required this.continuousModelBorder,
    required this.headingFont,
    required this.userFont,
    required this.modelFont,
    required this.settingsFont,
    required this.monoFont,
    required this.userFontScale,
    required this.modelFontScale,
    required this.favoriteModels,
  });

  final bool loading;
  final String? apiKey;

  /// Whether the active API key was seeded from [SettingsNotifier.apiKeyEnvVar]
  /// rather than saved on the device. Such a key lives only for this session.
  final bool apiKeyFromEnvironment;
  final String defaultModel;
  final ThemeMode themeMode;
  final String? downloadDir;
  final bool animateModelIndicator;
  final bool continuousModelBorder;
  final AppFont headingFont;
  final AppFont userFont;
  final AppFont modelFont;
  final AppFont settingsFont;
  final AppFont monoFont;
  final double userFontScale;
  final double modelFontScale;
  final Set<String> favoriteModels;

  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  /// Name of the environment variable consulted for the API key.
  String get apiKeyEnvVarName => SettingsNotifier.apiKeyEnvVar;

  bool isFavoriteModel(String id) => favoriteModels.contains(id);
}

/// Holds user settings: the API key, the default model for new chats, and the
/// app theme mode. The API key lives in secure storage; the rest in prefs.
class SettingsNotifier extends Notifier<SettingsState> {
  late final SecureStorageService _secureStorage;
  late final SharedPreferences _prefs;
  late final Map<String, String> _environment;

  static const _kDefaultModel = 'default_model';
  static const _kThemeMode = 'theme_mode';
  static const _kDownloadDir = 'download_dir';
  static const _kAnimateModelIndicator = 'animate_model_indicator';
  static const _kContinuousModelBorder = 'continuous_model_border';
  static const _kHeadingFont = 'font_heading';
  static const _kUserFont = 'font_user';
  static const _kModelFont = 'font_model';
  static const _kSettingsFont = 'font_settings';
  static const _kMonoFont = 'font_mono';
  static const _kUserFontScale = 'font_scale_user';
  static const _kModelFontScale = 'font_scale_model';
  static const _kFavoriteModels = 'favorite_models';

  /// Environment variable read at startup (desktop) to seed the API key when
  /// none is stored on the device.
  static const apiKeyEnvVar = 'OPENROUTER_API_KEY';

  /// Allowed text-size multipliers for chat messages.
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.6;

  String? _apiKey;
  bool _apiKeyFromEnv = false;
  String _defaultModel = 'openai/gpt-4o-mini';
  ThemeMode _themeMode = ThemeMode.system;
  String? _downloadDir;
  bool _animateModelIndicator = false;
  bool _continuousModelBorder = false;
  // Roboto Condensed is the default app font (bundled asset).
  AppFont _headingFont = AppFont.robotoCondensed;
  AppFont _userFont = AppFont.robotoCondensed;
  AppFont _modelFont = AppFont.robotoCondensed;
  AppFont _settingsFont = AppFont.robotoCondensed;
  // JetBrains Mono is the default for code/JSON (debug panel).
  AppFont _monoFont = AppFont.jetBrainsMono;
  // Text-size multipliers for chat messages (1.0 == default size).
  double _userFontScale = 1.0;
  double _modelFontScale = 1.0;
  Set<String> _favoriteModels = {};
  bool _loading = true;

  @override
  SettingsState build() {
    _secureStorage = ref.read(secureStorageProvider);
    _prefs = ref.read(sharedPreferencesProvider);
    _environment = ref.read(environmentProvider);
    _load();
    return _snapshot();
  }

  SettingsState _snapshot() => SettingsState(
        loading: _loading,
        apiKey: _apiKey,
        apiKeyFromEnvironment: _apiKeyFromEnv,
        defaultModel: _defaultModel,
        themeMode: _themeMode,
        downloadDir: _downloadDir,
        animateModelIndicator: _animateModelIndicator,
        continuousModelBorder: _continuousModelBorder,
        headingFont: _headingFont,
        userFont: _userFont,
        modelFont: _modelFont,
        settingsFont: _settingsFont,
        monoFont: _monoFont,
        userFontScale: _userFontScale,
        modelFontScale: _modelFontScale,
        favoriteModels: _favoriteModels,
      );

  void _emit() => state = _snapshot();

  bool get _hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> _load() async {
    try {
      _apiKey = await _secureStorage.readApiKey();
    } catch (_) {
      _apiKey = null;
    }
    // No key saved on the device? On desktop, fall back to the environment.
    if (!_hasApiKey) _applyEnvFallback();
    _defaultModel = _prefs.getString(_kDefaultModel) ?? _defaultModel;
    _downloadDir = _prefs.getString(_kDownloadDir);
    _animateModelIndicator = _prefs.getBool(_kAnimateModelIndicator) ?? false;
    _continuousModelBorder = _prefs.getBool(_kContinuousModelBorder) ?? false;
    const def = AppFont.robotoCondensed; // default app font
    _headingFont = AppFontX.fromIndex(_prefs.getInt(_kHeadingFont) ?? def.index);
    _userFont = AppFontX.fromIndex(_prefs.getInt(_kUserFont) ?? def.index);
    _modelFont = AppFontX.fromIndex(_prefs.getInt(_kModelFont) ?? def.index);
    _settingsFont =
        AppFontX.fromIndex(_prefs.getInt(_kSettingsFont) ?? def.index);
    _monoFont = AppFontX.fromIndex(
        _prefs.getInt(_kMonoFont) ?? AppFont.jetBrainsMono.index);
    _userFontScale = _clampScale(_prefs.getDouble(_kUserFontScale) ?? 1.0);
    _modelFontScale = _clampScale(_prefs.getDouble(_kModelFontScale) ?? 1.0);
    _favoriteModels =
        (_prefs.getStringList(_kFavoriteModels) ?? const []).toSet();
    final themeIndex = _prefs.getInt(_kThemeMode);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    _loading = false;
    _emit();
  }

  Future<void> setDownloadDir(String? dir) async {
    _downloadDir = (dir != null && dir.isNotEmpty) ? dir : null;
    if (_downloadDir != null) {
      await _prefs.setString(_kDownloadDir, _downloadDir!);
    } else {
      await _prefs.remove(_kDownloadDir);
    }
    _emit();
  }

  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isNotEmpty) {
      // An explicitly entered key is stored on the device and overrides any
      // environment value.
      _apiKey = trimmed;
      _apiKeyFromEnv = false;
      await _secureStorage.writeApiKey(trimmed);
    } else {
      // Saving an empty key clears the stored one; fall back to the env value.
      await _secureStorage.deleteApiKey();
      _apiKey = null;
      _apiKeyFromEnv = false;
      _applyEnvFallback();
    }
    _emit();
  }

  Future<void> clearApiKey() async {
    await _secureStorage.deleteApiKey();
    _apiKey = null;
    _apiKeyFromEnv = false;
    // Reverting a stored key exposes the environment value again, if present.
    _applyEnvFallback();
    _emit();
  }

  /// Seeds [_apiKey] from the environment when nothing is stored on the device.
  void _applyEnvFallback() {
    final envKey = _environment[apiKeyEnvVar]?.trim();
    if (envKey != null && envKey.isNotEmpty) {
      _apiKey = envKey;
      _apiKeyFromEnv = true;
    }
  }

  Future<void> setDefaultModel(String model) async {
    _defaultModel = model;
    await _prefs.setString(_kDefaultModel, model);
    _emit();
  }

  Future<void> setAnimateModelIndicator(bool value) async {
    _animateModelIndicator = value;
    await _prefs.setBool(_kAnimateModelIndicator, value);
    _emit();
  }

  Future<void> setContinuousModelBorder(bool value) async {
    _continuousModelBorder = value;
    await _prefs.setBool(_kContinuousModelBorder, value);
    _emit();
  }

  Future<void> setHeadingFont(AppFont f) async {
    _headingFont = f;
    await _prefs.setInt(_kHeadingFont, f.index);
    _emit();
  }

  Future<void> setUserFont(AppFont f) async {
    _userFont = f;
    await _prefs.setInt(_kUserFont, f.index);
    _emit();
  }

  Future<void> setModelFont(AppFont f) async {
    _modelFont = f;
    await _prefs.setInt(_kModelFont, f.index);
    _emit();
  }

  Future<void> setSettingsFont(AppFont f) async {
    _settingsFont = f;
    await _prefs.setInt(_kSettingsFont, f.index);
    _emit();
  }

  Future<void> setMonoFont(AppFont f) async {
    _monoFont = f;
    await _prefs.setInt(_kMonoFont, f.index);
    _emit();
  }

  Future<void> setUserFontScale(double scale) async {
    _userFontScale = _clampScale(scale);
    await _prefs.setDouble(_kUserFontScale, _userFontScale);
    _emit();
  }

  Future<void> setModelFontScale(double scale) async {
    _modelFontScale = _clampScale(scale);
    await _prefs.setDouble(_kModelFontScale, _modelFontScale);
    _emit();
  }

  double _clampScale(double v) => v.clamp(minFontScale, maxFontScale);

  Future<void> toggleFavoriteModel(String id) async {
    // Copy so listeners that captured the old set see a distinct value.
    final next = Set<String>.from(_favoriteModels);
    if (!next.remove(id)) next.add(id);
    _favoriteModels = next;
    await _prefs.setStringList(_kFavoriteModels, next.toList());
    _emit();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    _emit();
  }
}
