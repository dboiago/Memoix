import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../models/recipe_bundle.dart';
import '../models/storage_meta.dart';
import '../services/repository_manager.dart';
import 'cloud_storage_provider.dart';
import 'external_storage_provider.dart';

/// Google Drive implementation of CloudStorageProvider and ExternalStorageProvider
///
/// Uses OAuth 2.0 via google_sign_in on mobile, and loopback OAuth on desktop.
/// See EXTERNAL_STORAGE.md Section 7.1 for implementation details.
class GoogleDriveStorage implements CloudStorageProvider, ExternalStorageProvider {
  // Storage keys
  static const _keyFolderId = 'google_drive_folder_id';
  static const _keyFolderPath = 'google_drive_folder_path';
  static const _keyIsConnected = 'google_drive_connected';
  static const _keyAccessToken = 'google_drive_access_token';
  static const _keyRefreshToken = 'google_drive_refresh_token';
  static const _keyTokenExpiry = 'google_drive_token_expiry';

  // File names in the Memoix folder
  static const _recipesFileName = 'memoix_recipes.json';
  static const _metaFileName = '.memoix_meta.json';
  static const _defaultFolderName = 'Memoix';

  // MIME types
  static const _folderMimeType = 'application/vnd.google-apps.folder';
  static const _jsonMimeType = 'application/json';

  // OAuth scopes
  static const _scopes = [drive.DriveApi.driveFileScope];

  /// Desktop OAuth ClientId - loaded from .env or falls back to dev keys
  static auth_io.ClientId get _desktopClientId => auth_io.ClientId(
    ApiConfig.googleClientIdDesktop,
    ApiConfig.googleClientSecretDesktop,
  );

  /// Google Sign-In instance for mobile platforms
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  /// Drive API client (initialized after sign-in)
  drive.DriveApi? _driveApi;

  /// Authenticated HTTP client
  http.Client? _authClient;

  /// Cached folder ID for the Memoix folder
  String? _folderId;

  /// Cached folder display path
  String? _folderPath;

  /// Connection state
  bool _isConnected = false;

  /// Desktop credentials (for token refresh)
  auth_io.AccessCredentials? _desktopCredentials;

  // --- Platform detection ---

  /// Returns true if running on a desktop platform (Windows, macOS, Linux)
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Returns true if running on a mobile platform (Android, iOS)
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // --- ExternalStorageProvider interface ---

  @override
  String get name => 'Google Drive';

  @override
  String get id => 'google_drive';

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
  bool get isConnected => _isConnected;

  @override
  String? get connectedPath => _folderPath;

  /// Initialize provider and restore connection state from preferences
  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isConnected = prefs.getBool(_keyIsConnected) ?? false;
    _folderId = prefs.getString(_keyFolderId);
    _folderPath = prefs.getString(_keyFolderPath);

    // Try to restore session if we have stored credentials
    // (even if _isConnected is false, e.g., after switching from another provider)
    try {
      if (_isDesktop) {
        await _restoreDesktopSession(prefs);
        // If session was restored successfully, mark as connected
        if (_driveApi != null) {
          _isConnected = true;
          await prefs.setBool(_keyIsConnected, true);
        }
      } else if (_isMobile) {
        await _restoreMobileSession();
        // _restoreMobileSession already sets _isConnected
      }
      
      // After successful session restoration, check pending repositories
      if (_isConnected) {
        unawaited(checkPendingRepositories());
      }
    } catch (e) {
      debugPrint('GoogleDriveStorage: Silent sign-in failed: $e');
      await _clearStoredState();
    }
  }

  @override
  Future<bool> connect() async {
    try {
      bool connected = false;
      if (_isDesktop) {
        connected = await _connectDesktop();
      } else if (_isMobile) {
        connected = await _connectMobile();
      } else {
        throw UnsupportedError('Platform not supported for Google Drive');
      }

      // After successful connection, check pending repositories
      if (connected) {
        // Run verification in background (don't await to not block connection)
        unawaited(checkPendingRepositories());
      }

      return connected;
    } catch (e) {
      debugPrint('GoogleDriveStorage: Connection failed: $e');
      await _clearStoredState();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_isMobile) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('GoogleDriveStorage: Sign out error: $e');
    }

    _driveApi = null;
    _authClient?.close();
    _authClient = null;
    _desktopCredentials = null;
    await _clearStoredState();
  }

  // --- CloudStorageProvider interface ---

  /// Initialize the provider (wrapper for initialize())
  @override
  Future<void> init() async {
    await initialize();
  }

  /// Sign in to Google Drive (wrapper for connect())
  @override
  Future<void> signIn() async {
    await connect();
  }

  /// Sign out from Google Drive (wrapper for disconnect())
  @override
  Future<void> signOut() async {
    await disconnect();
  }

  /// Sync recipes (push local data to cloud)
  @override
  Future<void> syncRecipes() async {
    // This is typically called from ExternalStorageService.push()
    // For direct CloudStorageProvider usage, we would need to:
    // 1. Get RecipeBundle from local database
    // 2. Call push(bundle)
    // For now, this delegates to the service layer
    throw UnimplementedError('Use ExternalStorageService.push() instead');
  }

  // --- Repository Sharing ---

  /// Add write permission for a user by email
  /// 
  /// This allows sharing a repository folder with another Google account.
  /// The recipient will have Editor (writer) access to the folder.
  /// 
  /// Throws [Exception] if:
  /// - Not connected
  /// - Invalid email format
  /// - API call fails (e.g., 400 for invalid email)
  Future<void> addPermission(String folderId, String email) async {
    _ensureConnected();

    if (_driveApi == null) {
      throw Exception('Drive API not initialized');
    }

    // Validate email format (basic check)
    if (!email.contains('@') || !email.contains('.')) {
      throw Exception('Invalid email address');
    }

    try {
      final permission = drive.Permission()
        ..type = 'user'
        ..role = 'writer'
        ..emailAddress = email;

      await _driveApi!.permissions.create(
        permission,
        folderId,
        sendNotificationEmail: true, // Google will send invite email
      );
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 400) {
        throw Exception('Invalid email address or permission request');
      } else if (e.status == 403) {
        throw Exception('Permission denied. You may not have permission to share this folder.');
      } else if (e.status == 404) {
        throw Exception('Folder not found');
      }
      throw Exception('Failed to add permission: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add permission: $e');
    }
  }

  /// Verify access to a folder by ID
  ///
  /// Returns true if the folder exists and is accessible.
  /// Throws an exception if offline or connection fails.
  Future<bool> verifyFolderAccess(String folderId) async {
    _ensureConnected();

    if (_driveApi == null) {
      throw Exception('Drive API not initialized');
    }

    try {
      final file = await _driveApi!.files.get(
        folderId,
        $fields: 'id,name',
      ) as drive.File;

      return file.id != null;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403) {
        return false; // Access denied
      } else if (e.status == 404) {
        return false; // Not found
      }
      rethrow; // Connection errors, etc.
    }
  }

  /// Create a new folder in Google Drive root
  ///
  /// Returns the new folder ID.
  /// Used when creating a new repository.
  /// 
  /// Handles first-time users by attempting silent sign-in,
  /// then falling back to interactive sign-in if needed.
  Future<String> createFolder(String name) async {
    // Ensure we have a connection
    if (_driveApi == null) {
      // Not connected yet - attempt to establish connection
      try {
        if (_isDesktop) {
          // Desktop: Try to restore session, fallback to interactive
          final prefs = await SharedPreferences.getInstance();
          try {
            await _restoreDesktopSession(prefs);
          } catch (e) {
            debugPrint('GoogleDriveStorage: Silent sign-in failed, triggering interactive sign-in');
            // Silent restore failed - trigger interactive sign-in
            await _connectDesktop();
          }
        } else if (_isMobile) {
          // Mobile: Try silent sign-in first
          final account = await _googleSignIn.signInSilently();
          if (account == null) {
            // Silent sign-in failed - trigger interactive sign-in
            debugPrint('GoogleDriveStorage: Silent sign-in failed, triggering interactive sign-in');
            final signedInAccount = await _googleSignIn.signIn();
            if (signedInAccount == null) {
              throw Exception('User cancelled sign-in');
            }
            await _initializeDriveApiFromMobile(signedInAccount);
            await _setupMemoixFolder();
          } else {
            await _initializeDriveApiFromMobile(account);
          }
        }
      } catch (e) {
        throw Exception('Failed to establish Drive connection: $e');
      }
    }

    _ensureConnected();

    if (_driveApi == null) {
      throw Exception('Drive API not initialized after connection attempt');
    }

    try {
      final folderMetadata = drive.File()
        ..name = name
        ..mimeType = _folderMimeType
        ..parents = ['root'];

      final createdFolder = await _driveApi!.files.create(folderMetadata);

      if (createdFolder.id == null) {
        throw Exception('Failed to create folder');
      }

      debugPrint('GoogleDriveStorage: Created folder "$name" with ID: ${createdFolder.id}');
      return createdFolder.id!;
    } catch (e) {
      throw Exception('Failed to create folder: $e');
    }
  }

  /// Switch to a different repository
  ///
  /// This updates the target folder for all subsequent operations.
  /// Called when user switches active repository in Repository Management.
  Future<void> switchRepository(String folderId, String repositoryName) async {
    _ensureConnected();

    // Verify access to new folder
    final hasAccess = await verifyFolderAccess(folderId);
    if (!hasAccess) {
      throw Exception('Cannot access repository folder');
    }

    // Update cached values
    _folderId = folderId;
    _folderPath = '/My Drive/$repositoryName';
    await _saveStoredState();

    debugPrint('GoogleDriveStorage: Switched to repository "$repositoryName"');
  }

  /// Check and verify pending repositories on app startup
  ///
  /// This is called automatically after successful connection to verify
  /// repositories that were added while offline (via deep links).
  Future<void> checkPendingRepositories() async {
    if (!_isConnected) {
      debugPrint('GoogleDriveStorage: Not connected, skipping pending verification');
      return;
    }

    final manager = RepositoryManager();
    final pending = await manager.getPendingRepositories();

    if (pending.isEmpty) {
      debugPrint('GoogleDriveStorage: No pending repositories to verify');
      return;
    }

    debugPrint('GoogleDriveStorage: Verifying ${pending.length} pending repositories');

    for (final repo in pending) {
      try {
        final hasAccess = await verifyFolderAccess(repo.folderId);

        if (hasAccess) {
          // Success - mark as verified
          await manager.markAsVerified(repo.id);
          debugPrint('GoogleDriveStorage: Verified repository "${repo.name}"');
          
          // Show success notification
          // Note: SnackBar requires BuildContext, so we use debugPrint for now
          // The UI will show updated status when user opens Repository Management
        } else {
          // Access denied (403 or 404)
          await manager.markAsAccessDenied(repo.id);
          debugPrint('GoogleDriveStorage: Access denied for repository "${repo.name}"');
        }
      } catch (e) {
        // Network error or other issue - leave as pending
        debugPrint('GoogleDriveStorage: Could not verify "${repo.name}": $e');
        // Will retry on next app launch
      }
    }

    debugPrint('GoogleDriveStorage: Pending verification complete');
  }

  @override
  Future<void> push(RecipeBundle bundle) async {
    _ensureConnected();

    final folderId = await _ensureFolderId();
    final content = bundle.toJsonString(pretty: true);

    // Upload the recipes file
    await _uploadFile(
      folderId: folderId,
      fileName: _recipesFileName,
      content: content,
      mimeType: _jsonMimeType,
    );

    // Update lastSynced timestamp for this repository
    final manager = RepositoryManager();
    final activeRepo = await manager.getActiveRepository();
    if (activeRepo != null) {
      await manager.updateLastSynced(activeRepo.id);
    }
  }

  @override
  Future<RecipeBundle?> pull() async {
    _ensureConnected();

    final folderId = await _ensureFolderId();

    try {
      final content = await _downloadFile(
        folderId: folderId,
        fileName: _recipesFileName,
      );

      if (content == null) {
        return null;
      }

      final bundle = RecipeBundle.fromJsonString(content);

      // Update lastSynced timestamp for this repository
      final manager = RepositoryManager();
      final activeRepo = await manager.getActiveRepository();
      if (activeRepo != null) {
        await manager.updateLastSynced(activeRepo.id);
      }

      return bundle;
    } catch (e) {
      debugPrint('GoogleDriveStorage: Pull failed: $e');
      return null;
    }
  }

  @override
  Future<StorageMeta?> getMeta() async {
    _ensureConnected();

    final folderId = await _ensureFolderId();

    try {
      final content = await _downloadFile(
        folderId: folderId,
        fileName: _metaFileName,
      );

      if (content == null) {
        return null;
      }

      final json = jsonDecode(content) as Map<String, dynamic>;
      return StorageMeta.fromJson(json);
    } catch (e) {
      debugPrint('GoogleDriveStorage: Get meta failed: $e');
      return null;
    }
  }

  @override
  Future<void> updateMeta(StorageMeta meta) async {
    _ensureConnected();

    final folderId = await _ensureFolderId();
    final content = const JsonEncoder.withIndent('  ').convert(meta.toJson());

    await _uploadFile(
      folderId: folderId,
      fileName: _metaFileName,
      content: content,
      mimeType: _jsonMimeType,
    );
  }

  // --- Platform-specific connection methods ---

  /// Connect on mobile using google_sign_in
  Future<bool> _connectMobile() async {
    // Sign out first to ensure we get a fresh token
    await _googleSignIn.signOut();

    // Trigger OAuth consent flow
    final account = await _googleSignIn.signIn();
    if (account == null) {
      // User cancelled
      return false;
    }

    // Initialize Drive API
    await _initializeDriveApiFromMobile(account);

    // Get or create the Memoix folder
    await _setupMemoixFolder();

    return true;
  }

  /// Connect on desktop using loopback OAuth flow
  Future<bool> _connectDesktop() async {
    // Use the loopback OAuth flow which opens a browser
    final client = await auth_io.clientViaUserConsent(
      _desktopClientId,
      _scopes,
      _launchAuthUrl,
    );

    _authClient = client;
    _desktopCredentials = client.credentials;
    _driveApi = drive.DriveApi(client);

    // Save credentials for later restoration
    await _saveDesktopCredentials(_desktopCredentials!);

    // Get or create the Memoix folder
    await _setupMemoixFolder();

    return true;
  }

  /// Launch the OAuth URL in the user's browser
  void _launchAuthUrl(String url) {
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Restore mobile session (silent sign-in)
  Future<void> _restoreMobileSession() async {
    final account = await _googleSignIn.signInSilently();
    if (account != null) {
      await _initializeDriveApiFromMobile(account);
    } else {
      // Token expired or revoked - clear connection state
      await _clearStoredState();
    }
  }

  /// Restore desktop session from stored tokens
  Future<void> _restoreDesktopSession(SharedPreferences prefs) async {
    final accessToken = prefs.getString(_keyAccessToken);
    final refreshToken = prefs.getString(_keyRefreshToken);
    final expiryMillis = prefs.getInt(_keyTokenExpiry);

    if (accessToken == null || refreshToken == null || expiryMillis == null) {
      await _clearStoredState();
      return;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    final credentials = auth_io.AccessCredentials(
      auth_io.AccessToken('Bearer', accessToken, expiry.toUtc()),
      refreshToken,
      _scopes,
    );

    // Check if token needs refresh
    if (expiry.isBefore(DateTime.now())) {
      try {
        final refreshedCredentials = await auth_io.refreshCredentials(
          _desktopClientId,
          credentials,
          http.Client(),
        );
        _desktopCredentials = refreshedCredentials;
        await _saveDesktopCredentials(refreshedCredentials);
      } catch (e) {
        debugPrint('GoogleDriveStorage: Token refresh failed: $e');
        await _clearStoredState();
        return;
      }
    } else {
      _desktopCredentials = credentials;
    }

    // Create authenticated client
    final client = auth_io.authenticatedClient(
      http.Client(),
      _desktopCredentials!,
    );
    _authClient = client;
    _driveApi = drive.DriveApi(client);
  }

  /// Save desktop credentials to SharedPreferences
  Future<void> _saveDesktopCredentials(auth_io.AccessCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, creds.accessToken.data);
    if (creds.refreshToken != null) {
      await prefs.setString(_keyRefreshToken, creds.refreshToken!);
    }
    await prefs.setInt(
      _keyTokenExpiry,
      creds.accessToken.expiry.millisecondsSinceEpoch,
    );
  }

  /// Initialize Drive API from mobile sign-in
  Future<void> _initializeDriveApiFromMobile(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    _authClient = _GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(_authClient!);
  }

  /// Setup Memoix folder after successful connection
  Future<void> _setupMemoixFolder() async {
    final folderId = await _getOrCreateMemoixFolder();
    _folderId = folderId;
    _folderPath = '/My Drive/$_defaultFolderName';
    _isConnected = true;

    // Persist connection state
    await _saveStoredState();
  }

  // --- Public methods for folder selection ---

  /// Get list of folders in the user's Drive for folder picker
  /// Returns folders that the app has access to.
  Future<List<DriveFolder>> listFolders({String? parentId}) async {
    _ensureConnected();

    final parent = parentId ?? 'root';
    final query =
        "mimeType='$_folderMimeType' and '$parent' in parents and trashed=false";

    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name)',
      orderBy: 'name',
    );

    return fileList.files
            ?.map((f) => DriveFolder(id: f.id!, name: f.name!))
            .toList() ??
        [];
  }

  /// Check if a Memoix folder already exists in the user's Drive
  Future<String?> findExistingMemoixFolder() async {
    _ensureConnected();

    final query =
        "mimeType='$_folderMimeType' and name='$_defaultFolderName' and trashed=false";

    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }
    return null;
  }

  /// Set the folder to use for storage (after user selection)
  Future<void> setFolder({
    required String folderId,
    required String folderPath,
  }) async {
    _folderId = folderId;
    _folderPath = folderPath;
    await _saveStoredState();
  }

  /// Check if remote folder has existing Memoix data
  Future<bool> hasExistingData() async {
    _ensureConnected();

    final folderId = await _ensureFolderId();

    try {
      final query =
          "name='$_recipesFileName' and '$folderId' in parents and trashed=false";

      final fileList = await _driveApi!.files.list(
        q: query,
        $fields: 'files(id)',
      );

      return fileList.files != null && fileList.files!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get recipe count from remote (quick check via meta)
  Future<int?> getRemoteRecipeCount() async {
    final meta = await getMeta();
    return meta?.recipeCount;
  }

  // --- Private methods ---

  /// Ensure we have a valid Drive API connection
  void _ensureConnected() {
    if (_driveApi == null) {
      throw StateError(
        'Not connected to Google Drive. Call connect() first.',
      );
    }
  }

  /// Get the folder ID, fetching from preferences if needed
  /// Get the folder ID for the active repository
  ///
  /// Migration Path:
  /// - If no active repository exists (first run / legacy user):
  ///   1. Search for legacy 'Memoix' folder (or create if brand new user)
  ///   2. Register it as 'Default' repository in RepositoryManager
  ///   3. Set it as active
  /// - If active repository exists: Use its folderId
  Future<String> _ensureFolderId() async {
    // Use cached folder ID if available
    if (_folderId != null) {
      return _folderId!;
    }

    final manager = RepositoryManager();
    final activeRepo = await manager.getActiveRepository();

    if (activeRepo != null) {
      // Active repository exists - use it
      debugPrint('GoogleDriveStorage: Using active repository: ${activeRepo.name}');
      _folderId = activeRepo.folderId;
      _folderPath = '/My Drive/${activeRepo.name}';
    } else {
      // No active repository - MIGRATION PATH for existing users
      debugPrint('GoogleDriveStorage: No active repository - performing migration');

      // Search for legacy 'Memoix' folder or create new
      final legacyFolderId = await _getOrCreateMemoixFolder();

      // Register as 'Default' repository
      final defaultRepo = await manager.addRepository(
        name: 'Default',
        folderId: legacyFolderId,
        isPendingVerification: false,
      );

      debugPrint('GoogleDriveStorage: Migrated to repository system - registered "Default" repository');

      _folderId = legacyFolderId;
      _folderPath = '/My Drive/Memoix';
    }

    await _saveStoredState();
    return _folderId!;
  }

  /// Get the Memoix folder ID, creating it if it doesn't exist
  ///
  /// This implements the crucial logic from EXTERNAL_STORAGE.md:
  /// 1. Search for existing "Memoix" folder in root
  /// 2. If not found, create a new folder named "Memoix"
  /// 3. Return the folder ID for file operations
  Future<String> _getOrCreateMemoixFolder() async {
    _ensureConnected();

    // First, search for an existing Memoix folder in the root
    final existingFolderId = await findExistingMemoixFolder();
    if (existingFolderId != null) {
      debugPrint('GoogleDriveStorage: Found existing Memoix folder');
      return existingFolderId;
    }

    // Folder doesn't exist - create it
    debugPrint('GoogleDriveStorage: Creating new Memoix folder');

    final folderMetadata = drive.File()
      ..name = _defaultFolderName
      ..mimeType = _folderMimeType
      ..parents = ['root'];

    final createdFolder = await _driveApi!.files.create(folderMetadata);

    if (createdFolder.id == null) {
      throw Exception('Failed to create Memoix folder');
    }

    return createdFolder.id!;
  }

  /// Upload a file to the specified folder
  ///
  /// If the file already exists, it will be updated (overwritten).
  /// This ensures atomic writes as required by the provider contract.
  Future<void> _uploadFile({
    required String folderId,
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    _ensureConnected();

    // Check if file already exists
    final existingFileId = await _findFile(
      folderId: folderId,
      fileName: fileName,
    );

    final fileContent = Stream.value(utf8.encode(content));
    final media = drive.Media(fileContent, utf8.encode(content).length);

    if (existingFileId != null) {
      // Update existing file
      final file = drive.File()..name = fileName;

      await _driveApi!.files.update(
        file,
        existingFileId,
        uploadMedia: media,
      );

      debugPrint('GoogleDriveStorage: Updated $fileName');
    } else {
      // Create new file
      final file = drive.File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = [folderId];

      await _driveApi!.files.create(
        file,
        uploadMedia: media,
      );

      debugPrint('GoogleDriveStorage: Created $fileName');
    }
  }

  /// Download a file from the specified folder
  ///
  /// Returns null if the file doesn't exist.
  Future<String?> _downloadFile({
    required String folderId,
    required String fileName,
  }) async {
    _ensureConnected();

    final fileId = await _findFile(
      folderId: folderId,
      fileName: fileName,
    );

    if (fileId == null) {
      debugPrint('GoogleDriveStorage: File $fileName not found');
      return null;
    }

    // Download file content
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    // Read the stream into a string
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);

      // Security: Enforce 10 MB limit (AGENTS.md constraint)
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('File exceeds maximum allowed size (10 MB)');
      }
    }

    return utf8.decode(bytes);
  }

  /// Find a file by name in the specified folder
  ///
  /// Returns the file ID if found, null otherwise.
  Future<String?> _findFile({
    required String folderId,
    required String fileName,
  }) async {
    final query =
        "name='$fileName' and '$folderId' in parents and trashed=false";

    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }
    return null;
  }

  /// Save connection state to SharedPreferences
  Future<void> _saveStoredState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsConnected, _isConnected);
    if (_folderId != null) {
      await prefs.setString(_keyFolderId, _folderId!);
    }
    if (_folderPath != null) {
      await prefs.setString(_keyFolderPath, _folderPath!);
    }
  }

  /// Clear stored connection state
  Future<void> _clearStoredState() async {
    _isConnected = false;
    _folderId = null;
    _folderPath = null;
    _desktopCredentials = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsConnected);
    await prefs.remove(_keyFolderId);
    await prefs.remove(_keyFolderPath);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyTokenExpiry);
  }
}

/// HTTP client wrapper that adds Google auth headers (for mobile)
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

/// Represents a folder in Google Drive for the folder picker
class DriveFolder {
  final String id;
  final String name;

  const DriveFolder({
    required this.id,
    required this.name,
  });

  @override
  String toString() => 'DriveFolder(id: $id, name: $name)';
}

/// Provider for GoogleDriveStorage instance
final googleDriveStorageProvider = Provider<GoogleDriveStorage>((ref) {
  return GoogleDriveStorage();
});
