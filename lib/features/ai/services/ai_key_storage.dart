import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../import/ai/ai_provider.dart';

/// Secure storage for AI provider API keys.
///
/// Uses [FlutterSecureStorage] (Keychain on iOS, EncryptedSharedPreferences
/// on Android) so keys are never stored in plain text.
///
/// Keys are namespaced per [AiProvider] and never logged or printed.
class AiKeyStorage {
  AiKeyStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _prefix = 'ai_api_key_';

  /// Storage key for a provider.
  static String _key(AiProvider provider) => '$_prefix${provider.name}';

  /// Persist an API key for [provider].
  static Future<void> saveToken(AiProvider provider, String token) async {
    await _storage.write(key: _key(provider), value: token);
  }

  /// Read the API key for [provider]. Returns `null` when not set.
  static Future<String?> getToken(AiProvider provider) async {
    return _storage.read(key: _key(provider));
  }

  /// Remove the stored API key for [provider].
  static Future<void> clearToken(AiProvider provider) async {
    await _storage.delete(key: _key(provider));
  }

  /// Whether a key is stored for [provider].
  static Future<bool> hasToken(AiProvider provider) async {
    final value = await _storage.read(key: _key(provider));
    return value != null && value.isNotEmpty;
  }

  /// Remove all stored AI keys.
  static Future<void> clearAll() async {
    for (final provider in AiProvider.values) {
      await _storage.delete(key: _key(provider));
    }
  }
}
