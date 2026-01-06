import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for API credentials.
///
/// Uses a "Dual Key" strategy:
/// - Production builds use .env file with production keys
/// - Client IDs can have fallbacks (they're public)
/// - Client secrets MUST come from .env (not committed to repo)
///
/// The .env file is optional and loaded with isOptional: true
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
  /// MUST be provided via .env file - not committed to repo
  /// Returns null if not configured (will fail OAuth gracefully)
  static String? get googleClientSecretDesktop =>
      dotenv.maybeGet('GOOGLE_CLIENT_SECRET_DESKTOP');

  /// Google OAuth Client ID for Android
  /// Note: Android uses SHA-1 fingerprint verification, no secret needed
  static String get googleClientIdAndroid =>
      dotenv.maybeGet('GOOGLE_CLIENT_ID_ANDROID') ?? _fallbackAndroidClientId;

  /// Check if desktop OAuth is properly configured
  static bool get isDesktopOAuthConfigured =>
      googleClientSecretDesktop != null &&
      googleClientSecretDesktop!.isNotEmpty;
}
