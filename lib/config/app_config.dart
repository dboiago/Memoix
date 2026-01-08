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
        // 1. RELEASE MODE: Strict. Must use .env (Official)
        if (kReleaseMode) {
        final clientId = dotenv.maybeGet('ONEDRIVE_CLIENT_ID');
        if (clientId == null || clientId.isEmpty) {
            throw Exception(
            'CRITICAL: OneDrive Client ID missing for Release build. '
            'Ensure ONEDRIVE_CLIENT_ID is in your secure .env file.',
            );
        }
        return clientId;
        } 
        
        // 2. DEBUG/PROFILE MODE: Flexible. 
        // Try .env first (so you can test official flow), fall back to Hardcoded Dev Key.
        else {
        final envId = dotenv.maybeGet('ONEDRIVE_CLIENT_ID');
        if (envId != null && envId.isNotEmpty) {
            return envId;
        }
        
        // FALLBACK: The "Open Source" / Dev Key
        // This allows anyone to clone and run the app without your .env file.
        return '75b201da-5de0-416e-b908-a7a3899dbc9d'; 
        }
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
