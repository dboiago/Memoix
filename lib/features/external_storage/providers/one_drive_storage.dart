import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';
import '../../../core/services/graph_http_client.dart';
import 'cloud_storage_provider.dart';
/// Custom exception for repository not found errors
class RepositoryNotFoundException implements Exception {
  final String repositoryName;
  final String message;

  RepositoryNotFoundException(this.repositoryName, {String? customMessage})
      : message = customMessage ??
            'Repository "$repositoryName" not found in My Files or Shared with Me';

  @override
  String toString() => 'RepositoryNotFoundException: $message';
}
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
  static const _keyDriveId = 'onedrive_drive_id';
  static const _keyTargetFolderId = 'onedrive_target_folder_id';

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

  // State
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _activeFolderId;  // Current repository folder ID
  String? _activeFolderName;
  String? _targetDriveId;   // Drive ID where the repository folder resides
  String? _targetFolderId;  // Folder ID within the drive (same as _activeFolderId)
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
    _targetDriveId = await _secureStorage.read(key: _keyDriveId);
    _targetFolderId = await _secureStorage.read(key: _keyTargetFolderId);

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
  bool get isConnected {
    if (!_isConnected || _accessToken == null) {
      return false;
    }

    // Check if token is expired
    if (_tokenExpiry != null && _tokenExpiry!.isBefore(DateTime.now())) {
      // Token is expired - will need refresh on next operation
      return false;
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
      // Use _findRepository to locate the folder in My Files or Shared with Me
      final repoInfo = await _findRepository(name);
      
      final driveId = repoInfo['driveId'] as String;
      final targetFolderId = repoInfo['folderId'] as String;
      final isShared = repoInfo['isShared'] as bool;

      // Verify folder exists by fetching its metadata
      final verifyUrl = Uri.parse('$_graphApiBase/drives/$driveId/items/$targetFolderId');
      final response = await _httpClient!.get(verifyUrl);

      if (response.statusCode == 200) {
        _activeFolderId = targetFolderId;
        _activeFolderName = name;
        _targetDriveId = driveId;
        _targetFolderId = targetFolderId;

        // Persist to secure storage
        await _secureStorage.write(key: _keyFolderId, value: targetFolderId);
        await _secureStorage.write(key: _keyFolderName, value: name);
        await _secureStorage.write(key: _keyDriveId, value: driveId);
        await _secureStorage.write(key: _keyTargetFolderId, value: targetFolderId);

        final location = isShared ? 'Shared with Me' : 'My Files';
        debugPrint('OneDriveStorage: Switched to folder "$name" ($targetFolderId) in $location (drive: $driveId)');
      } else if (response.statusCode == 404) {
        throw Exception('Folder not found: $name ($folderId)');
      } else {
        throw Exception(
          'Failed to verify folder: ${response.statusCode} ${response.body}',
        );
      }
    } on RepositoryNotFoundException {
      // Re-throw with clear message
      rethrow;
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

  /// Find a repository folder by name in My Files or Shared with Me
  /// 
  /// First searches in the user's personal drive (/me/drive/root/children).
  /// If not found, searches in shared items (/me/drive/sharedWithMe).
  /// 
  /// For shared items, extracts the drive ID and folder ID from remoteItem.
  /// Returns a map with 'driveId', 'folderId', and 'isShared' keys.
  Future<Map<String, dynamic>> _findRepository(String repositoryName) async {
    _ensureConnected();

    try {
      // Step 1: Search in My Files (personal drive root)
      debugPrint('OneDriveStorage: Searching for "$repositoryName" in My Files...');
      
      final myFilesUrl = Uri.parse(
        '$_graphApiBase/me/drive/root/children?\$filter=name eq \'$repositoryName\'',
      );
      final myFilesResponse = await _httpClient!.get(myFilesUrl);

      if (myFilesResponse.statusCode == 200) {
        final myFilesData = jsonDecode(myFilesResponse.body) as Map<String, dynamic>;
        final items = myFilesData['value'] as List<dynamic>;

        if (items.isNotEmpty) {
          final folder = items.first as Map<String, dynamic>;
          final folderId = folder['id'] as String;
          
          // Get the drive ID from parentReference
          final parentRef = folder['parentReference'] as Map<String, dynamic>?;
          final driveId = parentRef?['driveId'] as String? ?? 'me';

          debugPrint('OneDriveStorage: Found "$repositoryName" in My Files (driveId: $driveId, folderId: $folderId)');
          
          return {
            'driveId': driveId,
            'folderId': folderId,
            'isShared': false,
          };
        }
      }

      // Step 2: Search in Shared with Me
      debugPrint('OneDriveStorage: Not found in My Files, searching Shared with Me...');
      
      final sharedUrl = Uri.parse('$_graphApiBase/me/drive/sharedWithMe');
      final sharedResponse = await _httpClient!.get(sharedUrl);

      if (sharedResponse.statusCode == 200) {
        final sharedData = jsonDecode(sharedResponse.body) as Map<String, dynamic>;
        final items = sharedData['value'] as List<dynamic>;

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name'] as String?;

          if (name == repositoryName) {
            // Extract drive and folder IDs from remoteItem
            final remoteItem = itemMap['remoteItem'] as Map<String, dynamic>?;
            
            if (remoteItem != null) {
              final parentRef = remoteItem['parentReference'] as Map<String, dynamic>?;
              final driveId = parentRef?['driveId'] as String?;
              final folderId = remoteItem['id'] as String?;

              if (driveId != null && folderId != null) {
                debugPrint('OneDriveStorage: Found "$repositoryName" in Shared with Me (driveId: $driveId, folderId: $folderId)');
                
                return {
                  'driveId': driveId,
                  'folderId': folderId,
                  'isShared': true,
                };
              }
            }
          }
        }
      }

      // Step 3: Not found in either location
      throw RepositoryNotFoundException(repositoryName);
      
    } catch (e) {
      if (e is RepositoryNotFoundException) {
        rethrow;
      }
      debugPrint('OneDriveStorage: _findRepository error: $e');
      rethrow;
    }
  }

  /// Upload a file to the active OneDrive folder
  Future<void> uploadFile(String fileName, String content) async {
    _ensureConnected();

    if (_targetDriveId == null || _targetFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      // Use ID-based URL with drive and folder IDs
      final url = Uri.parse(
        '$_graphApiBase/drives/$_targetDriveId/items/$_targetFolderId:/$fileName:/content',
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

    if (_targetDriveId == null || _targetFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      // Use ID-based URL with drive and folder IDs
      final url = Uri.parse(
        '$_graphApiBase/drives/$_targetDriveId/items/$_targetFolderId:/$fileName:/content',
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
