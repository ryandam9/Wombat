import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/conversation_store.dart';
import '../services/debug_log.dart';
import '../services/openrouter_service.dart';
import '../services/secure_storage_service.dart';

/// The loaded [SharedPreferences] instance. Overridden at startup in `main`
/// (and in tests) with a concrete instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Secure key/value store for the API key.
final secureStorageProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());

/// On-disk conversation persistence.
final conversationStoreProvider =
    Provider<ConversationStore>((ref) => ConversationStore());

/// Process environment variables, consulted on desktop to seed the API key.
/// Empty on mobile (and overridable in tests).
final environmentProvider = Provider<Map<String, String>>((ref) {
  try {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return Platform.environment;
    }
  } catch (_) {
    // Platform may be unavailable (e.g. web); fall through.
  }
  return const {};
});

/// The OpenRouter API client, wired to the debug log.
final openRouterServiceProvider = Provider<OpenRouterService>(
  (ref) => OpenRouterService(debug: ref.read(debugLogProvider.notifier)),
);
