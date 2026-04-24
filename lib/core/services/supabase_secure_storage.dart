import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSecureStorage extends LocalStorage {
  const SupabaseSecureStorage()
      : super(
          initialize: _initialize,
          hasAccessToken: _hasAccessToken,
          accessToken: _accessToken,
          persistSession: _persistSession,
          removeSession: _removeSession,
        );

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionKey = 'supabase.auth.token';

  static Future<void> _initialize() async {}

  static Future<bool> _hasAccessToken() async {
    return await _storage.containsKey(key: _sessionKey);
  }

  static Future<String?> _accessToken() async {
    return await _storage.read(key: _sessionKey);
  }

  static Future<void> _persistSession(String value) async {
    await _storage.write(key: _sessionKey, value: value);
  }

  static Future<void> _removeSession() async {
    await _storage.delete(key: _sessionKey);
  }
}