import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';
import '../../../core/services/graph_http_client.dart';
import 'cloud_storage_provider.dart';

/// OneDrive implementation of CloudStorageProvider
/// 
/// Uses Microsoft Graph API to interact with OneDrive storage.
/// Authentication is handled via OAuth2 using flutter_appauth.
/// Access tokens are securely stored using flutter_secure_storage.
class OneDriveStorage implements CloudStorageProvider {
  // Secure storage keys
  static const _keyAccessToken = 'onedrive_access_token';
  static const _keyRefreshToken = 'onedrive_refresh_token';
  static const _keyTokenExpiry = 'onedrive_token_expiry';
  static const _keyFolderId = 'onedrive_folder_id';
  static const _keyFolderName = 'onedrive_folder_name';

  // Microsoft Graph API endpoints
  static const _graphApiBase = 'https://graph.microsoft.com/v1.0';
  static const _authorizationEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const _tokenEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';

  // OAuth scopes
  static const _scopes = [
    'Files.ReadWrite',
    'Files.ReadWrite.All',
    'User.Read',
    'offline_access',
  ];

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _activeFolderId;
  String? _activeFolderName;
  GraphHttpClient? _httpClient;

  bool _isConnected = false;

  // --- CloudStorageProvider interface ---

  @override
  Future<void> init() async {
    // Restore previous session from secure storage
    _accessToken = await _secureStorage.read(key: _keyAccessToken);
    _refreshToken = await _secureStorage.read(key: _keyRefreshToken);
    _activeFolderId = await _secureStorage.read(key: _keyFolderId);
    _activeFolderName = await _secureStorage.read(key: _keyFolderName);

    final expiryStr = await _secureStorage.read(key: _keyTokenExpiry);
    if (expiryStr != null) {
      _tokenExpiry = DateTime.tryParse(expiryStr);
    }

    // Check if token is still valid
    if (_accessToken != null && _tokenExpiry != null) {
      if (_tokenExpiry!.isAfter(DateTime.now())) {
        _isConnected = true;
        _httpClient = GraphHttpClient(_accessToken!);
        debugPrint('OneDriveStorage: Session restored from secure storage');
      } else {
        // Token expired, try to refresh
        debugPrint('OneDriveStorage: Token expired, attempting refresh');
        await _refreshAccessToken();
      }
    }
  }

  @override
  Future<void> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConfig.oneDriveClientId,
          AppConfig.oneDriveRedirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _authorizationEndpoint,
            tokenEndpoint: _tokenEndpoint,
          ),
          scopes: _scopes,
        ),
      );

      if (result == null) {
        throw Exception('Sign in was cancelled by user');
      }

      // Store tokens securely
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      _tokenExpiry = result.accessTokenExpirationDateTime;

      await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
      await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
      await _secureStorage.write(
        key: _keyTokenExpiry,
        value: _tokenExpiry?.toIso8601String(),
      );

      _isConnected = true;
      _httpClient = GraphHttpClient(_accessToken!);

      debugPrint('OneDriveStorage: Sign in successful');
    } catch (e) {
      debugPrint('OneDriveStorage: Sign in failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Clear secure storage
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyTokenExpiry);
      await _secureStorage.delete(key: _keyFolderId);
      await _secureStorage.delete(key: _keyFolderName);

      // Clear in-memory state
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiry = null;
      _activeFolderId = null;
      _activeFolderName = null;
      _isConnected = false;

      _httpClient?.dispose();
      _httpClient = null;

      debugPrint('OneDriveStorage: Sign out successful');
    } catch (e) {
      debugPrint('OneDriveStorage: Sign out error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> get isConnected async {
    if (!_isConnected || _accessToken == null) {
      return false;
    }

    // Check if token is expired
    if (_tokenExpiry != null && _tokenExpiry!.isBefore(DateTime.now())) {
      // Try to refresh token
      try {
        await _refreshAccessToken();
        return _isConnected;
      } catch (e) {
        debugPrint('OneDriveStorage: Token refresh failed: $e');
        return false;
      }
    }

    return true;
  }

  @override
  Future<String> createFolder(String name) async {
    _ensureConnected();

    try {
      // Create folder in root of OneDrive
      final url = Uri.parse('$_graphApiBase/me/drive/root/children');
      final body = jsonEncode({
        'name': name,
        'folder': {},
        '@microsoft.graph.conflictBehavior': 'rename',
      });

      final response = await _httpClient!.post(url, body: body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final folderId = data['id'] as String;

        debugPrint('OneDriveStorage: Folder "$name" created with ID: $folderId');
        return folderId;
      } else {
        throw Exception(
          'Failed to create folder: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: createFolder error: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchRepository(String folderId, String name) async {
    _ensureConnected();

    try {
      // Verify folder exists
      final url = Uri.parse('$_graphApiBase/me/drive/items/$folderId');
      final response = await _httpClient!.get(url);

      if (response.statusCode == 200) {
        _activeFolderId = folderId;
        _activeFolderName = name;

        // Persist to secure storage
        await _secureStorage.write(key: _keyFolderId, value: folderId);
        await _secureStorage.write(key: _keyFolderName, value: name);

        debugPrint('OneDriveStorage: Switched to folder "$name" ($folderId)');
      } else if (response.statusCode == 404) {
        throw Exception('Folder not found: $folderId');
      } else {
        throw Exception(
          'Failed to verify folder: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: switchRepository error: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncRecipes() async {
    // This method is called from ExternalStorageService
    // The actual sync logic (creating RecipeBundle, etc.) lives in the service layer
    throw UnimplementedError(
      'OneDriveStorage: Use ExternalStorageService.push() for syncing',
    );
  }

  // --- Helper Methods ---

  /// Ensure user is connected, throw if not
  void _ensureConnected() {
    if (!_isConnected || _accessToken == null) {
      throw Exception('Not connected to OneDrive. Please sign in first.');
    }
  }

  /// Refresh the access token using the refresh token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final result = await _appAuth.token(
        TokenRequest(
          AppConfig.oneDriveClientId,
          AppConfig.oneDriveRedirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _authorizationEndpoint,
            tokenEndpoint: _tokenEndpoint,
          ),
          refreshToken: _refreshToken,
        ),
      );

      if (result == null) {
        throw Exception('Token refresh failed');
      }

      // Update tokens
      _accessToken = result.accessToken;
      if (result.refreshToken != null) {
        _refreshToken = result.refreshToken;
      }
      _tokenExpiry = result.accessTokenExpirationDateTime;

      // Save to secure storage
      await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
      if (_refreshToken != null) {
        await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
      }
      await _secureStorage.write(
        key: _keyTokenExpiry,
        value: _tokenExpiry?.toIso8601String(),
      );

      _isConnected = true;

      // Recreate HTTP client with new token
      _httpClient?.dispose();
      _httpClient = GraphHttpClient(_accessToken!);

      debugPrint('OneDriveStorage: Access token refreshed successfully');
    } catch (e) {
      debugPrint('OneDriveStorage: Token refresh error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// Upload a file to the active OneDrive folder
  Future<void> uploadFile(String fileName, String content) async {
    _ensureConnected();

    if (_activeFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      final url = Uri.parse(
        '$_graphApiBase/me/drive/items/$_activeFolderId:/$fileName:/content',
      );

      final response = await _httpClient!.put(
        url,
        body: utf8.encode(content),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OneDriveStorage: File "$fileName" uploaded successfully');
      } else {
        throw Exception(
          'Failed to upload file: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: uploadFile error: $e');
      rethrow;
    }
  }

  /// Download a file from the active OneDrive folder
  Future<String?> downloadFile(String fileName) async {
    _ensureConnected();

    if (_activeFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      final url = Uri.parse(
        '$_graphApiBase/me/drive/items/$_activeFolderId:/$fileName:/content',
      );

      final response = await _httpClient!.get(url);

      if (response.statusCode == 200) {
        debugPrint('OneDriveStorage: File "$fileName" downloaded successfully');
        return response.body;
      } else if (response.statusCode == 404) {
        debugPrint('OneDriveStorage: File "$fileName" not found');
        return null;
      } else {
        throw Exception(
          'Failed to download file: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: downloadFile error: $e');
      rethrow;
    }
  }
}
