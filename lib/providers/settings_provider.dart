import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_font.dart';
import '../services/secure_storage_service.dart';
import '../theme/app_theme.dart';
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
    this.apiKeyReadFailed = false,
    this.apiKeyRetrying = false,
    required this.defaultModel,
    required this.themeMode,
    required this.seedColor,
    this.bgColor,
    required this.downloadDir,
    required this.animateModelIndicator,
    required this.continuousModelBorder,
    required this.replyCompleteFeedback,
    required this.headingFont,
    required this.userFont,
    required this.modelFont,
    required this.settingsFont,
    required this.monoFont,
    required this.userFontScale,
    required this.modelFontScale,
    required this.favoriteModels,
    required this.userName,
    required this.aiName,
    required this.reduceMotion,
    required this.sidebarWidth,
    this.seenIntro = false,
  });

  final bool loading;
  final String? apiKey;

  /// Whether the active API key was seeded from [SettingsNotifier.apiKeyEnvVar]
  /// rather than saved on the device. Such a key lives only for this session.
  final bool apiKeyFromEnvironment;

  /// True when a key is stored on the device but the secure store couldn't be
  /// read this session (e.g. it was temporarily locked). The key is NOT gone —
  /// the UI should offer a retry rather than treat it as missing.
  final bool apiKeyReadFailed;

  /// True while a re-read of the secure store is in flight — either the manual
  /// Retry action or the automatic background recovery. The UI shows a progress
  /// indicator and disables Retry so the attempt reads as live.
  final bool apiKeyRetrying;
  final String defaultModel;
  final ThemeMode themeMode;

  /// Accent ("seed") colour both themes are generated from.
  final Color seedColor;

  /// Optional curated background tint (null → the theme default).
  final Color? bgColor;
  final String? downloadDir;
  final bool animateModelIndicator;
  final bool continuousModelBorder;

  /// Whether to play a haptic (mobile) or sound (desktop) cue when a model
  /// reply finishes streaming.
  final bool replyCompleteFeedback;
  final AppFont headingFont;
  final AppFont userFont;
  final AppFont modelFont;
  final AppFont settingsFont;
  final AppFont monoFont;
  final double userFontScale;
  final double modelFontScale;
  final Set<String> favoriteModels;

  /// Custom display name for the user's own messages (empty → "You").
  final String userName;

  /// Custom display name for AI replies (empty → the conversation's model).
  final String aiName;

  /// When true, app animations are shortened/disabled (also honoured when the
  /// platform requests reduced motion via `MediaQuery.disableAnimations`).
  final bool reduceMotion;

  /// Persisted width of the desktop sidebar.
  final double sidebarWidth;

  /// Whether the first-run intro has been shown.
  final bool seenIntro;

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
  static const _kSeedColor = 'seed_color';
  static const _kBgColor = 'bg_color';
  static const _kSeenIntro = 'seen_intro';
  static const _kDownloadDir = 'download_dir';
  static const _kAnimateModelIndicator = 'animate_model_indicator';
  static const _kContinuousModelBorder = 'continuous_model_border';
  static const _kReplyCompleteFeedback = 'reply_complete_feedback';
  static const _kHeadingFont = 'font_heading';
  static const _kUserFont = 'font_user';
  static const _kModelFont = 'font_model';
  static const _kSettingsFont = 'font_settings';
  static const _kMonoFont = 'font_mono';
  static const _kUserFontScale = 'font_scale_user';
  static const _kModelFontScale = 'font_scale_model';
  static const _kFavoriteModels = 'favorite_models';
  static const _kUserName = 'user_name';
  static const _kAiName = 'ai_name';
  static const _kReduceMotion = 'reduce_motion';
  static const _kSidebarWidth = 'sidebar_width';

  /// Default and bounds for the desktop sidebar width.
  static const double defaultSidebarWidth = 340;
  static const double minSidebarWidth = 220;
  static const double maxSidebarWidth = 520;

  /// Environment variable read at startup (desktop) to seed the API key when
  /// none is stored on the device.
  static const apiKeyEnvVar = 'OPENROUTER_API_KEY';

  /// Allowed text-size multipliers for chat messages.
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.6;

  String? _apiKey;
  bool _apiKeyFromEnv = false;
  bool _apiKeyReadFailed = false;
  bool _apiKeyRetrying = false;

  /// Monotonic token used to cancel an in-flight background recovery loop when
  /// it is superseded (a manual retry, the user saving/clearing a key, or the
  /// notifier being disposed).
  int _recoveryGen = 0;
  bool _disposed = false;
  String _defaultModel = 'openai/gpt-4o-mini';
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = AppTheme.defaultSeed;
  Color? _bgColor;
  bool _seenIntro = false;
  String? _downloadDir;
  bool _animateModelIndicator = false;
  bool _continuousModelBorder = false;
  bool _replyCompleteFeedback = true;
  // Roboto Condensed is the default app font (bundled asset).
  AppFont _headingFont = AppFont.robotoCondensed;
  AppFont _userFont = AppFont.robotoCondensed;
  AppFont _modelFont = AppFont.robotoCondensed;
  AppFont _settingsFont = AppFont.robotoCondensed;
  // Overpass Mono is the default for code/JSON (code blocks, debug panel).
  AppFont _monoFont = AppFont.overpassMono;
  // Text-size multipliers for chat messages (1.0 == default size).
  double _userFontScale = 1.0;
  double _modelFontScale = 1.0;
  Set<String> _favoriteModels = {};
  String _userName = '';
  String _aiName = '';
  bool _reduceMotion = false;
  double _sidebarWidth = defaultSidebarWidth;
  bool _loading = true;

  @override
  SettingsState build() {
    _secureStorage = ref.read(secureStorageProvider);
    _prefs = ref.read(sharedPreferencesProvider);
    _environment = ref.read(environmentProvider);
    // Stop any in-flight recovery loop and block emits once disposed, so a late
    // background retry never writes to a torn-down notifier.
    ref.onDispose(() {
      _disposed = true;
      _recoveryGen++;
    });
    _load();
    return _snapshot();
  }

  SettingsState _snapshot() => SettingsState(
        loading: _loading,
        apiKey: _apiKey,
        apiKeyFromEnvironment: _apiKeyFromEnv,
        apiKeyReadFailed: _apiKeyReadFailed,
        apiKeyRetrying: _apiKeyRetrying,
        defaultModel: _defaultModel,
        themeMode: _themeMode,
        seedColor: _seedColor,
        bgColor: _bgColor,
        seenIntro: _seenIntro,
        downloadDir: _downloadDir,
        animateModelIndicator: _animateModelIndicator,
        continuousModelBorder: _continuousModelBorder,
        replyCompleteFeedback: _replyCompleteFeedback,
        headingFont: _headingFont,
        userFont: _userFont,
        modelFont: _modelFont,
        settingsFont: _settingsFont,
        monoFont: _monoFont,
        userFontScale: _userFontScale,
        modelFontScale: _modelFontScale,
        favoriteModels: _favoriteModels,
        userName: _userName,
        aiName: _aiName,
        reduceMotion: _reduceMotion,
        sidebarWidth: _sidebarWidth,
      );

  void _emit() {
    if (_disposed) return;
    state = _snapshot();
  }

  bool get _hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> _load() async {
    await _readStoredApiKey();
    _defaultModel = _prefs.getString(_kDefaultModel) ?? _defaultModel;
    _downloadDir = _prefs.getString(_kDownloadDir);
    _animateModelIndicator = _prefs.getBool(_kAnimateModelIndicator) ?? false;
    _continuousModelBorder = _prefs.getBool(_kContinuousModelBorder) ?? false;
    _replyCompleteFeedback = _prefs.getBool(_kReplyCompleteFeedback) ?? true;
    const def = AppFont.robotoCondensed; // default app font
    _headingFont = AppFontX.fromIndex(_prefs.getInt(_kHeadingFont) ?? def.index);
    _userFont = AppFontX.fromIndex(_prefs.getInt(_kUserFont) ?? def.index);
    _modelFont = AppFontX.fromIndex(_prefs.getInt(_kModelFont) ?? def.index);
    _settingsFont =
        AppFontX.fromIndex(_prefs.getInt(_kSettingsFont) ?? def.index);
    _monoFont = AppFontX.fromIndex(
        _prefs.getInt(_kMonoFont) ?? AppFont.overpassMono.index);
    _userFontScale = _clampScale(_prefs.getDouble(_kUserFontScale) ?? 1.0);
    _modelFontScale = _clampScale(_prefs.getDouble(_kModelFontScale) ?? 1.0);
    _favoriteModels =
        (_prefs.getStringList(_kFavoriteModels) ?? const []).toSet();
    _userName = _prefs.getString(_kUserName) ?? '';
    _aiName = _prefs.getString(_kAiName) ?? '';
    _reduceMotion = _prefs.getBool(_kReduceMotion) ?? false;
    _sidebarWidth = (_prefs.getDouble(_kSidebarWidth) ?? defaultSidebarWidth)
        .clamp(minSidebarWidth, maxSidebarWidth);
    final themeIndex = _prefs.getInt(_kThemeMode);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    final seed = _prefs.getInt(_kSeedColor);
    if (seed != null) _seedColor = Color(seed);
    final bg = _prefs.getInt(_kBgColor);
    if (bg != null) _bgColor = Color(bg);
    _seenIntro = _prefs.getBool(_kSeenIntro) ?? false;
    _loading = false;
    _emit();
    // A locked store at launch is usually transient (Keystore warming up after
    // boot, the keyring not yet unlocked). Quietly keep trying in the
    // background so the key reappears on its own, without the user tapping
    // Retry.
    if (_apiKeyReadFailed) _autoRecoverApiKey();
  }

  /// Reads the stored key into [_apiKey], distinguishing "no key saved" (null)
  /// from "saved key couldn't be unlocked" (read threw). On a read failure the
  /// key is kept on the device and [_apiKeyReadFailed] is raised so the UI can
  /// offer a retry instead of re-prompting. The environment fallback applies
  /// only when the key is genuinely absent — never when a read failed, since a
  /// saved key may still be there.
  Future<void> _readStoredApiKey() async {
    try {
      _apiKey = await _secureStorage.readApiKey();
      _apiKeyReadFailed = false;
    } catch (_) {
      _apiKey = null;
      _apiKeyReadFailed = true;
    }
    if (!_hasApiKey && !_apiKeyReadFailed) _applyEnvFallback();
  }

  /// Backoff schedule for automatic secure-store recovery after a failed read.
  /// Short at first (most locks clear within a second or two), then spaced out.
  static const List<Duration> _recoveryBackoff = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
  ];

  /// Silently re-attempts the secure-store read on a backoff until the key is
  /// recovered, the attempts are exhausted, or the loop is superseded (a manual
  /// retry, the user saving/clearing a key, or disposal). Deliberately does NOT
  /// drive [apiKeyRetrying] — a long-running background loop must never freeze a
  /// spinner on screen; it only emits when it actually recovers the key.
  Future<void> _autoRecoverApiKey() async {
    final gen = ++_recoveryGen;
    for (final delay in _recoveryBackoff) {
      await Future<void>.delayed(delay);
      if (gen != _recoveryGen || _disposed) return; // superseded
      if (!_apiKeyReadFailed) return; // recovered elsewhere
      await _readStoredApiKey();
      if (gen != _recoveryGen || _disposed) return;
      if (_hasApiKey) {
        _emit(); // recovered on its own — surface it
        return;
      }
    }
  }

  /// Re-attempts reading the stored key after a prior read failure (the "Retry"
  /// action in Settings). Shows the brief [apiKeyRetrying] state for the single
  /// read, and — if it's still locked — resumes silent background recovery.
  /// Returns true when a key was recovered.
  Future<bool> reloadApiKey() async {
    final gen = ++_recoveryGen; // take ownership; cancel the background loop
    _apiKeyRetrying = true;
    _emit();
    try {
      await _readStoredApiKey();
    } finally {
      // Always clear the spinner (unless a newer owner already took over).
      if (gen == _recoveryGen && !_disposed) {
        _apiKeyRetrying = false;
        _emit();
      }
    }
    // Still locked → keep trying quietly in the background.
    if (gen == _recoveryGen && !_disposed && _apiKeyReadFailed) {
      _autoRecoverApiKey();
    }
    return _hasApiKey;
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

  /// Stores (or, for an empty value, clears) the API key. Returns true when the
  /// value was persisted to the secure store.
  ///
  /// A failing/locked secure store must never block the user: the key is always
  /// applied in memory for this session and the state is emitted regardless, so
  /// "Save" works even when the store can't be written. A persistence failure is
  /// reported (false) so the UI can warn that it won't survive a restart.
  Future<bool> setApiKey(String key) async {
    _recoveryGen++; // a user-provided key supersedes any background recovery
    _apiKeyRetrying = false;
    final trimmed = key.trim();
    var persisted = true;
    if (trimmed.isNotEmpty) {
      // Apply immediately so the user is never blocked, even if the write below
      // throws (the key still works for this session).
      _apiKey = trimmed;
      _apiKeyFromEnv = false;
      _apiKeyReadFailed = false;
      try {
        await _secureStorage.writeApiKey(trimmed);
      } catch (_) {
        persisted = false;
      }
    } else {
      // Saving an empty key clears the stored one; fall back to the env value.
      try {
        await _secureStorage.deleteApiKey();
      } catch (_) {
        persisted = false;
      }
      _apiKey = null;
      _apiKeyFromEnv = false;
      _apiKeyReadFailed = false;
      _applyEnvFallback();
    }
    _emit();
    return persisted;
  }

  Future<void> clearApiKey() async {
    _recoveryGen++; // clearing the key supersedes any background recovery
    _apiKeyRetrying = false;
    try {
      await _secureStorage.deleteApiKey();
    } catch (_) {/* best effort — still clear it from memory below */}
    _apiKey = null;
    _apiKeyFromEnv = false;
    _apiKeyReadFailed = false;
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

  /// Sets the display name shown on the user's own messages. Empty clears it
  /// (falling back to "You").
  Future<void> setUserName(String name) async {
    _userName = name.trim();
    await _prefs.setString(_kUserName, _userName);
    _emit();
  }

  /// Sets the display name shown on AI replies. Empty clears it (falling back
  /// to the conversation's model name).
  Future<void> setAiName(String name) async {
    _aiName = name.trim();
    await _prefs.setString(_kAiName, _aiName);
    _emit();
  }

  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    await _prefs.setBool(_kReduceMotion, value);
    _emit();
  }

  /// Persists the desktop sidebar width (clamped to the allowed range).
  Future<void> setSidebarWidth(double width) async {
    _sidebarWidth = width.clamp(minSidebarWidth, maxSidebarWidth);
    await _prefs.setDouble(_kSidebarWidth, _sidebarWidth);
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

  Future<void> setReplyCompleteFeedback(bool value) async {
    _replyCompleteFeedback = value;
    await _prefs.setBool(_kReplyCompleteFeedback, value);
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

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    await _prefs.setInt(_kSeedColor, color.toARGB32());
    _emit();
  }

  /// Sets (or clears, when [color] is null) the curated background tint.
  Future<void> setBgColor(Color? color) async {
    _bgColor = color;
    if (color == null) {
      await _prefs.remove(_kBgColor);
    } else {
      await _prefs.setInt(_kBgColor, color.toARGB32());
    }
    _emit();
  }

  /// Records that the first-run intro has been shown.
  Future<void> setSeenIntro(bool value) async {
    _seenIntro = value;
    await _prefs.setBool(_kSeenIntro, value);
    _emit();
  }
}
