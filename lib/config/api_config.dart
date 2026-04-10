import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for API credentials.
///
/// Reads credentials from the .env file (loaded with isOptional: true).
/// If .env is absent, Client IDs fall back to the embedded public values;
/// the Client Secret falls back to an empty string (OAuth will fail gracefully).
class ApiConfig {
  ApiConfig._();

  // --- Fallback Client IDs (safe to commit - these are public) ---

  static const _fallbackDesktopClientId =
      '633063631592-tdfp0blet25ua6c2g44621sc2stjpmq2.apps.googleusercontent.com';

  static const _fallbackAndroidClientId =
      '879187945656-5075c9jaa61lp7rko2n5qb0blpds8pn0.apps.googleusercontent.com';

  // --- Public Getters ---

  /// Google OAuth Client ID for Desktop (Windows/macOS/Linux)
  static String get googleClientIdDesktop =>
      dotenv.maybeGet('GOOGLE_CLIENT_ID_DESKTOP') ?? _fallbackDesktopClientId;

  /// Google OAuth Client Secret for Desktop
  /// Requires GOOGLE_CLIENT_SECRET_DESKTOP in .env — returns empty string if absent
  static String get googleClientSecretDesktop =>
      dotenv.maybeGet('GOOGLE_CLIENT_SECRET_DESKTOP') ?? '';

  /// Google OAuth Client ID for Android
  /// Note: Android uses SHA-1 fingerprint verification, no secret needed
  static String get googleClientIdAndroid =>
      dotenv.maybeGet('GOOGLE_CLIENT_ID_ANDROID') ?? _fallbackAndroidClientId;
      
  // DEPRECATED: Legacy IV for V1 Google Drive integration
  // Revoked 2025-11-14 following the security audit
  // ignore: unused_field
  static const List<int> _legacyIV = [
    0x45, 0x4E, 0x44, 0x4F, 0x46, 0x53, 0x45, 0x52, 
    0x56, 0x49, 0x43, 0x45, 0x21, 0x21, 0x21, 0x21
  ];

}
