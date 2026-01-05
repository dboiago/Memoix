import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe_bundle.dart';
import '../models/storage_meta.dart';
import 'external_storage_provider.dart';

/// Google Drive implementation of ExternalStorageProvider
///
/// Uses OAuth 2.0 via google_sign_in with drive.file scope (app-created files only).
/// See EXTERNAL_STORAGE.md Section 7.1 for implementation details.
class GoogleDriveStorage implements ExternalStorageProvider {
  // Storage keys
  static const _keyFolderId = 'google_drive_folder_id';
  static const _keyFolderPath = 'google_drive_folder_path';
  static const _keyIsConnected = 'google_drive_connected';

  // File names in the Memoix folder
  static const _recipesFileName = 'memoix_recipes.json';
  static const _metaFileName = '.memoix_meta.json';
  static const _defaultFolderName = 'Memoix';

  // MIME types
  static const _folderMimeType = 'application/vnd.google-apps.folder';
  static const _jsonMimeType = 'application/json';

  /// Google Sign-In instance with Drive file scope
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Drive API client (initialized after sign-in)
  drive.DriveApi? _driveApi;

  /// Authenticated HTTP client
  _GoogleAuthClient? _authClient;

  /// Cached folder ID for the Memoix folder
  String? _folderId;

  /// Cached folder display path
  String? _folderPath;

  /// Connection state
  bool _isConnected = false;

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
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isConnected = prefs.getBool(_keyIsConnected) ?? false;
    _folderId = prefs.getString(_keyFolderId);
    _folderPath = prefs.getString(_keyFolderPath);

    // If we were connected, try to silently sign in
    if (_isConnected) {
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          await _initializeDriveApi(account);
        } else {
          // Token expired or revoked - clear connection state
          await _clearStoredState();
        }
      } catch (e) {
        debugPrint('GoogleDriveStorage: Silent sign-in failed: $e');
        await _clearStoredState();
      }
    }
  }

  @override
  Future<bool> connect() async {
    try {
      // Sign out first to ensure we get a fresh token
      await _googleSignIn.signOut();

      // Trigger OAuth consent flow
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        return false;
      }

      // Initialize Drive API
      await _initializeDriveApi(account);

      // Get or create the Memoix folder
      final folderId = await _getOrCreateMemoixFolder();
      _folderId = folderId;
      _folderPath = '/My Drive/$_defaultFolderName';
      _isConnected = true;

      // Persist connection state
      await _saveStoredState();

      return true;
    } catch (e) {
      debugPrint('GoogleDriveStorage: Connection failed: $e');
      await _clearStoredState();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('GoogleDriveStorage: Sign out error: $e');
    }

    _driveApi = null;
    _authClient = null;
    await _clearStoredState();
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

      return RecipeBundle.fromJsonString(content);
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

  /// Initialize the Drive API with the signed-in account
  Future<void> _initializeDriveApi(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    _authClient = _GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(_authClient!);
  }

  /// Ensure we have a valid Drive API connection
  void _ensureConnected() {
    if (_driveApi == null) {
      throw StateError(
        'Not connected to Google Drive. Call connect() first.',
      );
    }
  }

  /// Get the folder ID, fetching from preferences if needed
  Future<String> _ensureFolderId() async {
    if (_folderId != null) {
      return _folderId!;
    }

    // Try to find or create the Memoix folder
    _folderId = await _getOrCreateMemoixFolder();
    _folderPath = '/My Drive/$_defaultFolderName';
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsConnected);
    await prefs.remove(_keyFolderId);
    await prefs.remove(_keyFolderPath);
  }
}

/// HTTP client wrapper that adds Google auth headers
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
