import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/services/graph_http_client.dart';
import '../models/recipe_bundle.dart';
import '../models/storage_meta.dart';
import 'cloud_storage_provider.dart';
import 'personal_storage_provider.dart';
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
class OneDriveStorage implements CloudStorageProvider, PersonalStorageProvider {
  // Secure storage keys
  static const _keyAccessToken = 'onedrive_access_token';
  static const _keyRefreshToken = 'onedrive_refresh_token';
  static const _keyTokenExpiry = 'onedrive_token_expiry';
  static const _keyFolderId = 'onedrive_folder_id';
  static const _keyFolderName = 'onedrive_folder_name';
  static const _keyDriveId = 'onedrive_drive_id';
  static const _keyTargetFolderId = 'onedrive_target_folder_id';

  // File names for storage files
  static const _recipesFileName = 'memoix_recipes.json';
  static const _metaFileName = '.memoix_meta.json';
  static const _databaseFileName = 'memoix.db';

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

  // --- PersonalStorageProvider interface ---

  @override
  String get name => 'Microsoft OneDrive';

  @override
  String get id => 'onedrive';

  @override
  bool get supportsAutomaticSync => true;

  @override
  bool get supportsFastMetaCheck => true;

  @override
  bool get supportsAtomicWrites => true;

  @override
  bool get supportsFolders => true;

  @override
  bool get isAdvanced => false;

  @override
  String? get connectedPath => _activeFolderName;

  @override
  Future<void> initialize() async {
    await init();
  }

  @override
  Future<bool> connect() async {
    await signIn();
    return isConnected;
  }

  @override
  Future<void> disconnect() async {
    await signOut();
  }

  @override
  Future<void> push(RecipeBundle bundle) async {
    _ensureConnected();
    final content = bundle.toJsonString(pretty: true);
    await uploadFile(_recipesFileName, content);
  }

  @override
  Future<RecipeBundle?> pull() async {
    _ensureConnected();
    final content = await downloadFile(_recipesFileName);
    if (content == null) return null;
    return RecipeBundle.fromJsonString(content);
  }

  @override
  Future<StorageMeta?> getMeta() async {
    _ensureConnected();
    try {
      final content = await downloadFile(_metaFileName);
      if (content == null) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return StorageMeta.fromJson(json);
    } catch (e) {
      debugPrint('OneDriveStorage: Get meta failed: $e');
      return null;
    }
  }

  @override
  Future<void> updateMeta(StorageMeta meta) async {
    _ensureConnected();
    final content = const JsonEncoder.withIndent('  ').convert(meta.toJson());
    await uploadFile(_metaFileName, content);
  }

  @override
  Future<void> pushDatabaseBytes(Uint8List bytes) async {
    _ensureConnected();
    await uploadFileBytes(_databaseFileName, bytes);
  }

  @override
  Future<Uint8List?> pullDatabaseBytes() async {
    _ensureConnected();
    return downloadFileBytes(_databaseFileName);
  }

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
      // Use platform-specific OAuth flow
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: Manual OAuth with loopback server
        await _signInDesktop();
      } else {
        // Mobile: Use flutter_appauth
        await _signInMobile();
      }

      _isConnected = true;
      _httpClient = GraphHttpClient(_accessToken!);

      debugPrint('OneDriveStorage: Sign in successful');
    } catch (e) {
      debugPrint('OneDriveStorage: Sign in failed: $e');
      rethrow;
    }
  }

  /// Mobile OAuth flow using flutter_appauth
  Future<void> _signInMobile() async {
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
    if (_refreshToken != null) {
      await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
    }
    await _secureStorage.write(
      key: _keyTokenExpiry,
      value: _tokenExpiry?.toIso8601String(),
    );
  }

  /// Desktop OAuth flow using loopback IP redirect
  Future<void> _signInDesktop() async {
    HttpServer? server;
    
    try {
      // Step A: Start local server on ephemeral port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      debugPrint('OneDriveStorage: Desktop OAuth server listening on $redirectUri');

      // Step B: Generate PKCE code verifier and challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // Step C: Construct authorization URL
      final authUrl = Uri.parse(_authorizationEndpoint).replace(
        queryParameters: {
          'client_id': AppConfig.oneDriveClientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'scope': _scopes.join(' '),
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      // Launch browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser for authentication');
      }

      // Step D: Listen for redirect
      final request = await server.first;
      final code = request.uri.queryParameters['code'];

      // Respond to browser
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html')
        ..write('<html><body><h1>Authentication Successful</h1>'
            '<p>You can close this window and return to Memoix.</p></body></html>');
      await request.response.close();

      if (code == null) {
        throw Exception('No authorization code received');
      }

      debugPrint('OneDriveStorage: Authorization code received');

      // Step E: Exchange code for tokens
      final tokenResponse = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': AppConfig.oneDriveClientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception(
          'Token exchange failed: ${tokenResponse.statusCode} ${tokenResponse.body}',
        );
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;

      // Step F: Store tokens
      _accessToken = tokenData['access_token'] as String?;
      _refreshToken = tokenData['refresh_token'] as String?;
      
      final expiresIn = tokenData['expires_in'] as int?;
      if (expiresIn != null) {
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      }

      await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
      if (_refreshToken != null) {
        await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
      }
      if (_tokenExpiry != null) {
        await _secureStorage.write(
          key: _keyTokenExpiry,
          value: _tokenExpiry!.toIso8601String(),
        );
      }

      debugPrint('OneDriveStorage: Desktop OAuth completed successfully');
    } finally {
      // Always close the server
      await server?.close();
    }
  }

  /// Generate a random code verifier for PKCE (43-128 characters)
  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generate SHA-256 code challenge from verifier
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
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
      await _secureStorage.delete(key: _keyDriveId);
      await _secureStorage.delete(key: _keyTargetFolderId);

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
      // Step 1: Try to resolve the folder by ID in the user's own drive.
      // This avoids the name-lookup ambiguity that existed previously.
      final myDriveUrl = Uri.parse('$_graphApiBase/me/drive/items/$folderId');
      final myDriveResponse = await _httpClient!.get(myDriveUrl);

      String driveId;
      final String targetFolderId = folderId;

      if (myDriveResponse.statusCode == 200) {
        final data = jsonDecode(myDriveResponse.body) as Map<String, dynamic>;
        final parentRef = data['parentReference'] as Map<String, dynamic>?;
        final resolvedDriveId = parentRef?['driveId'] as String?;
        // parentReference.driveId may be absent for root-level items on some
        // personal account configurations. Never fall back to the string 'me'
        // because it is invalid in /drives/{id}/ Graph API URLs.
        driveId = (resolvedDriveId != null && resolvedDriveId.isNotEmpty)
            ? resolvedDriveId
            : await _fetchOwnDriveId();
        debugPrint('OneDriveStorage: Resolved "$name" in own drive (driveId: $driveId)');
      } else {
        // Step 2: Search Shared with Me items for the supplied folder ID.
        debugPrint('OneDriveStorage: "$name" not in own drive, checking Shared with Me...');
        final sharedUrl = Uri.parse('$_graphApiBase/me/drive/sharedWithMe');
        final sharedResponse = await _httpClient!.get(sharedUrl);

        if (sharedResponse.statusCode != 200) {
          throw RepositoryNotFoundException(name,
              customMessage: 'Folder "$name" ($folderId) not found');
        }

        final sharedData = jsonDecode(sharedResponse.body) as Map<String, dynamic>;
        final items = sharedData['value'] as List<dynamic>;

        String? foundDriveId;
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final remoteItem = itemMap['remoteItem'] as Map<String, dynamic>?;
          final remoteId = remoteItem?['id'] as String?;
          if (remoteId == folderId) {
            final parentRef = remoteItem?['parentReference'] as Map<String, dynamic>?;
            foundDriveId = parentRef?['driveId'] as String?;
            break;
          }
        }

        if (foundDriveId == null) {
          throw RepositoryNotFoundException(name,
              customMessage:
                  'Folder "$name" ($folderId) not found in My Files or Shared with Me');
        }
        driveId = foundDriveId;
        debugPrint('OneDriveStorage: Resolved "$name" in Shared with Me (driveId: $driveId)');
      }

      // Step 3: Verify reachability using the resolved drive ID.
      final verifyUrl = Uri.parse('$_graphApiBase/drives/$driveId/items/$targetFolderId');
      final response = await _httpClient!.get(verifyUrl);

      if (response.statusCode == 200) {
        // Update in-memory state only — do NOT persist to secure storage here.
        // Persisting here would overwrite the personal Memoix folder keys with
        // the shared repo's IDs, breaking personal backup on next app launch.
        // Persistence is only done explicitly via _persistFolderState(), which
        // is called from setupDefaultFolder() for the personal Memoix folder.
        _activeFolderId = targetFolderId;
        _activeFolderName = name;
        _targetDriveId = driveId;
        _targetFolderId = targetFolderId;

        debugPrint('OneDriveStorage: Switched to folder "$name" ($targetFolderId) on drive $driveId');
      } else if (response.statusCode == 404) {
        throw Exception('Folder not found: $name ($folderId)');
      } else {
        throw Exception(
          'Failed to verify folder: ${response.statusCode} ${response.body}',
        );
      }
    } on RepositoryNotFoundException {
      rethrow;
    } catch (e) {
      debugPrint('OneDriveStorage: switchRepository error: $e');
      rethrow;
    }
  }

  /// Verify access to a folder by ID.
  ///
  /// Returns true if the folder is reachable with the current credentials.
  /// Used by [_verifyStorage] in SharedStorageScreen for OneDrive repositories.
  Future<bool> verifyFolderAccess(String folderId) async {
    if (!_isConnected || _httpClient == null) return false;
    try {
      // If we already have the target drive ID cached, use it first.
      if (_targetDriveId != null) {
        final url = Uri.parse('$_graphApiBase/drives/$_targetDriveId/items/$folderId');
        final response = await _httpClient!.get(url);
        if (response.statusCode == 200) return true;
        if (response.statusCode == 403) return false;
      }
      // Fallback: try via the user's own drive root.
      final url = Uri.parse('$_graphApiBase/me/drive/items/$folderId');
      final response = await _httpClient!.get(url);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch the user's own OneDrive drive ID via GET /me/drive.
  ///
  /// Used as a fallback when parentReference.driveId is absent from an item
  /// metadata response. Never returns 'me' — throws on failure.
  Future<String> _fetchOwnDriveId() async {
    final url = Uri.parse('$_graphApiBase/me/drive');
    final response = await _httpClient!.get(url);
    if (response.statusCode != 200) {
      throw Exception(
        'OneDriveStorage: Failed to fetch own drive ID: '
        '${response.statusCode} ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('OneDriveStorage: /me/drive did not return a valid id');
    }
    debugPrint('OneDriveStorage: Own drive ID fetched: $id');
    return id;
  }

  /// Find or create the default "Memoix" folder in the user's OneDrive root,
  /// then call [switchRepository] to set all target fields.
  ///
  /// This mirrors [GoogleDriveStorage._setupMemoixFolder] and is called from
  /// [personal_storage_screen._connectOneDrive] after a successful sign-in.
  Future<void> setupDefaultFolder() async {
    _ensureConnected();

    const defaultName = 'Memoix';

    // Search for an existing Memoix folder at root level.
    final searchUrl = Uri.parse(
      '$_graphApiBase/me/drive/root/children?\$filter=name eq \'$defaultName\'',
    );
    final searchResponse = await _httpClient!.get(searchUrl);

    String folderId;

    if (searchResponse.statusCode == 200) {
      final data = jsonDecode(searchResponse.body) as Map<String, dynamic>;
      final items = data['value'] as List<dynamic>;
      if (items.isNotEmpty) {
        final existing = items.first as Map<String, dynamic>;
        folderId = existing['id'] as String;
        debugPrint('OneDriveStorage: Found existing Memoix folder: $folderId');
      } else {
        // Not found — create it.
        folderId = await createFolder(defaultName);
        debugPrint('OneDriveStorage: Created Memoix folder: $folderId');
      }
    } else {
      // Search failed — create a new folder.
      folderId = await createFolder(defaultName);
      debugPrint('OneDriveStorage: Created Memoix folder (search failed): $folderId');
    }

    await switchRepository(folderId, defaultName);

    // Persist the personal Memoix folder state so it survives app restarts.
    // This is the ONLY place that writes to the personal folder secure-storage
    // keys. switchRepository() is deliberately in-memory-only to prevent
    // shared repo switches from contaminating personal storage state.
    await _persistFolderState();
  }

  /// Persist the current folder state to secure storage.
  ///
  /// Called only from [setupDefaultFolder] to save the personal Memoix folder.
  /// Must NOT be called from [switchRepository] so shared repo operations
  /// stay isolated from personal backup preferences.
  Future<void> _persistFolderState() async {
    if (_targetFolderId != null) {
      await _secureStorage.write(key: _keyTargetFolderId, value: _targetFolderId);
    }
    if (_targetDriveId != null) {
      await _secureStorage.write(key: _keyDriveId, value: _targetDriveId);
    }
    if (_activeFolderId != null) {
      await _secureStorage.write(key: _keyFolderId, value: _activeFolderId);
    }
    if (_activeFolderName != null) {
      await _secureStorage.write(key: _keyFolderName, value: _activeFolderName);
    }
  }

  /// Check if remote folder already contains an existing memoix_recipes.json file.
  ///
  /// Returns true if the file exists, false if not found or an error occurs.
  /// Used in the connect flow to decide whether to push (first-time) or pull.
  Future<bool> hasExistingData() async {
    if (!isConnected || _targetDriveId == null || _targetFolderId == null) {
      return false;
    }
    try {
      final url = Uri.parse(
        '$_graphApiBase/drives/$_targetDriveId/items/$_targetFolderId:/$_recipesFileName',
      );
      final response = await _httpClient!.get(url);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Grant folder permission to a user by email.
  ///
  /// OneDrive folder sharing via Microsoft Graph is not yet implemented.
  /// Use the share link instead.
  Future<void> addPermission(String folderId, String email) async {
    throw UnimplementedError(
      'OneDrive email invitations are not yet supported. Use the share link instead.',
    );
  }

  @override
  Future<void> syncRecipes() async {
    // This method is called from PersonalStorageService
    // The actual sync logic (creating RecipeBundle, etc.) lives in the service layer
    throw UnimplementedError(
      'OneDriveStorage: Use PersonalStorageService.push() for syncing',
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
      // On Windows, use manual HTTP request since flutter_appauth doesn't support it
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _refreshTokenDesktop();
      } else {
        await _refreshTokenMobile();
      }

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

  /// Refresh token using flutter_appauth (mobile/web)
  Future<void> _refreshTokenMobile() async {
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
  }

  /// Refresh token using manual HTTP request (desktop)
  Future<void> _refreshTokenDesktop() async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': AppConfig.oneDriveClientId,
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Token refresh failed: ${response.statusCode} ${response.body}',
      );
    }

    final tokenData = jsonDecode(response.body) as Map<String, dynamic>;

    // Update tokens
    _accessToken = tokenData['access_token'] as String?;
    if (tokenData['refresh_token'] != null) {
      _refreshToken = tokenData['refresh_token'] as String?;
    }
    
    final expiresIn = tokenData['expires_in'] as int?;
    if (expiresIn != null) {
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    }

    // Save to secure storage
    await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
    if (_refreshToken != null) {
      await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
    }
    if (_tokenExpiry != null) {
      await _secureStorage.write(
        key: _keyTokenExpiry,
        value: _tokenExpiry!.toIso8601String(),
      );
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

  /// Upload raw bytes to the active OneDrive folder
  Future<void> uploadFileBytes(String fileName, Uint8List bytes) async {
    _ensureConnected();

    if (_targetDriveId == null || _targetFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      final url = Uri.parse(
        '$_graphApiBase/drives/$_targetDriveId/items/$_targetFolderId:/$fileName:/content',
      );

      final response = await _httpClient!.put(
        url,
        body: bytes,
        headers: {'Content-Type': 'application/octet-stream'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OneDriveStorage: File "$fileName" (bytes) uploaded successfully');
      } else {
        throw Exception(
          'Failed to upload file: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: uploadFileBytes error: $e');
      rethrow;
    }
  }

  /// Download raw bytes from the active OneDrive folder
  Future<Uint8List?> downloadFileBytes(String fileName) async {
    _ensureConnected();

    if (_targetDriveId == null || _targetFolderId == null) {
      throw Exception('No active folder selected');
    }

    try {
      final url = Uri.parse(
        '$_graphApiBase/drives/$_targetDriveId/items/$_targetFolderId:/$fileName:/content',
      );

      final response = await _httpClient!.get(url);

      if (response.statusCode == 200) {
        debugPrint('OneDriveStorage: File "$fileName" (bytes) downloaded successfully');
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        debugPrint('OneDriveStorage: File "$fileName" not found');
        return null;
      } else {
        throw Exception(
          'Failed to download file: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('OneDriveStorage: downloadFileBytes error: $e');
      rethrow;
    }
  }
}
