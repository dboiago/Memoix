import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration for external services
///
/// Reads credentials from the .env file (loaded with isOptional: true).
/// If a key is absent, the relevant OAuth flow fails gracefully at the server side.
class AppConfig {
  AppConfig._();

  // --- OneDrive OAuth Configuration ---

  /// OneDrive Client ID from Azure App Registration
  ///
  /// Requires ONEDRIVE_CLIENT_ID in .env — returns empty string if absent.
  static String get oneDriveClientId =>
      dotenv.maybeGet('ONEDRIVE_CLIENT_ID') ?? '';

  /// OneDrive Redirect URI for OAuth callback
  /// 
  /// Default: memoix://oauth/callback
  /// This must match the redirect URI configured in Azure App Registration.
  /// 
  /// To override, add to .env file:
  /// ONEDRIVE_REDIRECT_URI=your-custom-uri
  static String get oneDriveRedirectUri =>
      dotenv.maybeGet('ONEDRIVE_REDIRECT_URI') ?? 'io.github.dboiago.memoix://oauth/callback';
}
