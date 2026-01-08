import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration for external services
/// 
/// Provides access to OneDrive OAuth credentials from .env file.
/// Fallback values will be added once Azure App Registration is complete.
class AppConfig {
  AppConfig._();

  // --- OneDrive OAuth Configuration ---

  /// OneDrive Client ID from Azure App Registration
  /// 
  /// To set this value, add to .env file:
  /// ONEDRIVE_CLIENT_ID=your-client-id-here
  static String get oneDriveClientId {
    final clientId = dotenv.maybeGet('ONEDRIVE_CLIENT_ID');
    if (clientId == null || clientId.isEmpty) {
      throw Exception(
        'OneDrive Client ID not configured. '
        'Please add ONEDRIVE_CLIENT_ID to your .env file.',
      );
    }
    return clientId;
  }

  /// OneDrive Redirect URI for OAuth callback
  /// 
  /// Default: memoix://oauth/callback
  /// This must match the redirect URI configured in Azure App Registration.
  /// 
  /// To override, add to .env file:
  /// ONEDRIVE_REDIRECT_URI=your-custom-uri
  static String get oneDriveRedirectUri =>
      dotenv.maybeGet('ONEDRIVE_REDIRECT_URI') ?? 'memoix://oauth/callback';
}
