import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the OpenRouter API key in the platform secure store
/// (Keystore on Android, libsecret on Linux, Keychain on macOS).
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _apiKeyKey = 'openrouter_api_key';
  final FlutterSecureStorage _storage;

  Future<String?> readApiKey() => _storage.read(key: _apiKeyKey);

  Future<void> writeApiKey(String value) =>
      _storage.write(key: _apiKeyKey, value: value);

  Future<void> deleteApiKey() => _storage.delete(key: _apiKeyKey);
}
