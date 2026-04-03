import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../mealplan/models/meal_plan.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../models/storage_location.dart';
import '../models/merge_result.dart';
import '../models/storage_meta.dart';
import '../models/sync_mode.dart';
import '../models/sync_status.dart';
import '../providers/personal_storage_provider.dart';
import 'shared_storage_manager.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';

/// Preference keys for external storage settings
class _PrefKeys {
  static const lastSyncTime = 'personal_storage_last_sync';
  static const syncMode = 'personal_storage_sync_mode';
  static const connectedProviderId = 'personal_storage_provider_id';
  static const connectedPath = 'personal_storage_path';
}

/// Core service for external storage sync operations
/// 
/// Handles push/pull logic, merge strategy, and app lifecycle integration.
/// See EXTERNAL_STORAGE.md Section 8 for architecture details.
class PersonalStorageService {
  final Ref _ref;
  PersonalStorageProvider? _provider;
  
  /// Debounce timer for batching rapid recipe changes
  Timer? _pushDebouncer;
  
  /// Guards against concurrent push operations
  bool _isPushing = false;
  
  /// Guards against concurrent pull operations
  bool _isPulling = false;
  
  /// Tracks if there are pending local changes not yet pushed
  bool _hasPendingChanges = false;
  
  /// Tracks if initialization has completed
  bool _isInitialized = false;

  /// Prevents automatic push when the last pull failed.
  /// Protects remote data from being overwritten by local data that may be
  /// incompatible with the remote schema. Cleared on successful pull or push.
  bool _pullFailed = false;

  /// Minimum time between automatic syncs (5 minutes)
  static const _syncCooldown = Duration(minutes: 5);
  
  /// Debounce delay for batching recipe saves (5 seconds)
  static const _pushDebounceDelay = Duration(seconds: 5);
  
  /// Maximum retry attempts for failed operations
  static const _maxRetries = 3;
  
  /// Base delay for exponential backoff (doubles each retry)
  static const _baseRetryDelay = Duration(seconds: 1);

  PersonalStorageService(this._ref);

  // ============ INITIALIZATION ============

  /// Initialize the service by restoring any previously connected provider
  /// 
  /// This should be called once at app startup to restore the connection state.
  /// See EXTERNAL_STORAGE.md Section 8.1 for architecture details.
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent double initialization
    
    final prefs = await SharedPreferences.getInstance();
    final providerId = prefs.getString(_PrefKeys.connectedProviderId);
    
    if (providerId == null) {
      // No provider was connected
      _isInitialized = true;
      return;
    }
    
    try {
      // Instantiate the appropriate provider based on stored ID
      final provider = _createProvider(providerId);
      if (provider == null) {
        debugPrint('PersonalStorageService: Unknown provider ID: $providerId');
        _isInitialized = true;
        return;
      }
      
      // Initialize the provider (handles silent sign-in)
      await provider.initialize();
      
      if (provider.isConnected) {
        _provider = provider;
        debugPrint('PersonalStorageService: Restored connection to ${provider.name}');
        
        // If there were pending changes queued before initialization, trigger push
        if (_hasPendingChanges && !_pullFailed) {
          final isAuto = await isAutomaticMode;
          if (isAuto) {
            debugPrint('PersonalStorageService: Flushing pending changes after init');
            push(silent: true);
          }
        }
      } else {
        // Silent sign-in failed (token expired/revoked)
        // Clear stored state so user can reconnect
        await prefs.remove(_PrefKeys.connectedProviderId);
        debugPrint('PersonalStorageService: Failed to restore ${provider.name} connection');
      }
    } catch (e) {
      debugPrint('PersonalStorageService: Provider restoration error: $e');
      // Don't throw - just leave provider as null, user can reconnect manually
    }
    
    _isInitialized = true;
  }
  
  /// Create a provider instance by ID
  PersonalStorageProvider? _createProvider(String providerId) {
    switch (providerId) {
      case 'google_drive':
        // Use the Riverpod singleton to prevent two instances with diverging
        // in-memory state (e.g. _folderId set on one but not the other after
        // switchRepository() is called from the UI).
        return _ref.read(googleDriveStorageProvider);
      case 'onedrive':
        return OneDriveStorage();
      // Add other providers here as they are implemented:
      // case 'github':
      //   return GitHubStorage();
      // case 'icloud':
      //   return ICloudStorage();
      default:
        return null;
    }
  }
  
  /// Execute an async operation with retry and exponential backoff
  /// 
  /// Implements the retry logic from EXTERNAL_STORAGE.md Section 10:
  /// - Silent retry up to _maxRetries times
  /// - Exponential backoff: 1s, 2s, 4s
  /// - After all retries fail, throws the last error
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    Object? lastError;
    
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        debugPrint(
          'PersonalStorageService: $operationName attempt $attempt/$_maxRetries failed: $e',
        );
        
        if (attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          final delay = _baseRetryDelay * math.pow(2, attempt - 1).toInt();
          debugPrint('PersonalStorageService: Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }
    
    // All retries exhausted
    throw lastError!;
  }

  // ============ PUBLIC GETTERS ============

  /// Whether a storage provider is currently connected
  bool get isConnected => _provider?.isConnected ?? false;

  /// Currently connected provider (null if none)
  PersonalStorageProvider? get provider => _provider;

  /// Current sync mode setting
  Future<SyncMode> get syncMode async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_PrefKeys.syncMode);
    if (value == null) return SyncMode.manual;
    return SyncMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => SyncMode.manual,
    );
  }

  /// Whether automatic mode is enabled
  Future<bool> get isAutomaticMode async {
    final mode = await syncMode;
    return mode == SyncMode.automatic;
  }

  /// Get last sync timestamp (public getter for UI)
  Future<DateTime?> get lastSyncTime => _getLastSyncTime();

  // ============ CONNECTION MANAGEMENT ============

  /// Set the active storage provider
  Future<void> setProvider(PersonalStorageProvider provider) async {
    _provider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.connectedProviderId, provider.id);
    if (provider.connectedPath != null) {
      await prefs.setString(_PrefKeys.connectedPath, provider.connectedPath!);
    }
  }

  /// Disconnect and clear the current provider
  Future<void> disconnect() async {
    await _provider?.disconnect();
    _provider = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefKeys.connectedProviderId);
    await prefs.remove(_PrefKeys.connectedPath);
    // NOTE: Do NOT remove lastSyncTime - we want to remember the user has synced before
    // This prevents showing the "Existing Data Found" dialog on reconnect
    
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
  }

  /// Set the sync mode (manual/automatic)
  Future<void> setSyncMode(SyncMode mode) async {
    // Validate: don't allow automatic mode for providers that don't support it
    if (mode == SyncMode.automatic && 
        _provider != null && 
        !_provider!.supportsAutomaticSync) {
      throw UnsupportedError(
        '${_provider!.name} does not support automatic sync mode',
      );
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.syncMode, mode.name);
  }

  // ============ APP LIFECYCLE HOOKS ============

  /// Called on app startup
  /// Restores provider connection and triggers smart pull if automatic mode.
  Future<void> onAppLaunched() async {
    // Restore provider connection from persisted state
    if (_provider == null) {
      await initialize();
    }
    
    if (!isConnected) return;
    if (!await isAutomaticMode) return;

    final lastSync = await _getLastSyncTime();
    if (lastSync == null || 
        DateTime.now().difference(lastSync) > _syncCooldown) {
      await pull(silent: true);
    }
  }

  /// Called after recipe save/delete
  /// Debounces and batches rapid changes before pushing.
  void onRecipeChanged() {
    // Always mark pending changes - even if not yet initialized
    // This ensures we don't lose changes that happen during app startup
    _hasPendingChanges = true;
    
    // If not initialized yet, the pending flag will trigger push after init
    if (!_isInitialized || !isConnected || _pullFailed) return;
    
    // Check sync mode asynchronously
    isAutomaticMode.then((isAuto) {
      if (!isAuto) return;
      
      // Cancel any pending debounce timer
      _pushDebouncer?.cancel();
      
      // Start new debounce timer
      _pushDebouncer = Timer(_pushDebounceDelay, () {
        push(silent: true);
      });
    });
  }

  /// Called when app goes to background
  /// Flushes any pending changes immediately.
  Future<void> onAppBackgrounded() async {
    if (!isConnected) return;
    if (!await isAutomaticMode) return;

    // Cancel debouncer and push immediately if pending
    _pushDebouncer?.cancel();
    _pushDebouncer = null;
    
    if (_hasPendingChanges && !_pullFailed) {
      await push(silent: true);
    }
  }

  // ============ PUSH OPERATION ============

  /// Push local data to remote storage as a raw SQLite database file.
  ///
  /// [silent] - If true, show minimal UI feedback (for automatic syncs)
  /// Implements retry with exponential backoff per EXTERNAL_STORAGE.md Section 10.
  Future<void> push({bool silent = false}) async {
    if (_provider == null) {
      if (!silent) MemoixSnackBar.showError('No storage provider connected');
      return;
    }

    if (_isPushing) return; // Prevent concurrent pushes

    // Guard: refuse automatic push when the last pull failed to prevent
    // overwriting remote data that the local code cannot currently parse.
    if (_pullFailed && silent) {
      debugPrint(
        'PersonalStorageService: Skipping silent push — last pull failed; '
        'push manually to confirm intent',
      );
      return;
    }

    _isPushing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pushing;

    try {
      final db = AppDatabase.instance;

      // Flush WAL to main DB file before reading bytes
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      // Locate database file (same path used by driftDatabase(name: 'memoix'))
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/memoix.db');

      // One-time log: first push supersedes legacy memoix_recipes.json format
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pss_db_format_active') != true) {
        debugPrint(
          'PersonalStorageService: Switching to memoix.db format; '
          'supersedes legacy memoix_recipes.json',
        );
        await prefs.setBool('pss_db_format_active', true);
      }

      final bytes = await dbFile.readAsBytes();

      // Push to remote with retry logic
      await _withRetry(
        () async {
          await _provider!.pushDatabaseBytes(bytes);

          // Update meta file (kept for UI display)
          final meta = StorageMeta.create(
            deviceName: await _getDeviceName(),
            domains: const DomainCounts(),
          );
          await _provider!.updateMeta(meta);
        },
        operationName: 'push',
      );

      // Update last sync time in preferences
      final syncTime = DateTime.now();
      await _setLastSyncTime(syncTime);
      _hasPendingChanges = false;
      _pullFailed = false; // successful push clears the pull-failure guard

      // Update lastSynced timestamp in active repository
      final repositoriesJson = prefs.getString('drive_repositories');
      if (repositoriesJson != null) {
        final List<dynamic> list = jsonDecode(repositoriesJson);
        final repositories = list.map((item) =>
          StorageLocation.fromJson(item as Map<String, dynamic>)
        ).toList();

        // Find and update active repository
        final updated = repositories.map((r) {
          if (r.isActive) {
            return r.copyWith(lastSynced: syncTime);
          }
          return r;
        }).toList();

        // Save updated repositories
        final updatedJson = jsonEncode(updated.map((r) => r.toJson()).toList());
        await prefs.setString('drive_repositories', updatedJson);
      }

      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;

      if (!silent) {
        MemoixSnackBar.showSuccess('Database pushed');
      }
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      if (!silent) {
        MemoixSnackBar.showError('Push failed: $e');
      }
      debugPrint('PersonalStorageService.push error: $e');
    } finally {
      _isPushing = false;
    }
  }

  // ============ PULL OPERATION ============

  /// Pull remote data by downloading the raw SQLite database file and replacing
  /// the local database.
  ///
  /// [silent] - If true, show minimal UI feedback (for automatic syncs)
  /// Implements retry with exponential backoff per EXTERNAL_STORAGE.md Section 10.
  Future<PullResult> pull({bool silent = false}) async {
    if (_provider == null) {
      if (!silent) MemoixSnackBar.showError('No storage provider connected');
      return PullResult.failed('No storage provider connected');
    }

    if (_isPulling) return PullResult.skipped(); // Prevent concurrent pulls
    _isPulling = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pulling;

    try {
      // Smart pull: check meta first if provider supports it
      if (_provider!.supportsFastMetaCheck) {
        final remoteMeta = await _withRetry(
          () => _provider!.getMeta(),
          operationName: 'getMeta',
        );
        if (remoteMeta != null) {
          final lastSync = await _getLastSyncTime();
          if (lastSync != null && !remoteMeta.isNewerThan(lastSync)) {
            _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
            if (!silent) {
              MemoixSnackBar.show('Already up to date');
            }
            return PullResult.skipped();
          }
        }
      }

      // Download raw database bytes
      final bytes = await _withRetry(
        () => _provider!.pullDatabaseBytes(),
        operationName: 'pull',
      );

      if (bytes == null) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
        if (!silent) {
          MemoixSnackBar.show('No database found in storage');
        }
        return PullResult.skipped();
      }

      // Locate local database file
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/memoix.db');
      final tempFile = File('${dir.path}/memoix_sync_tmp.db');

      // Write downloaded bytes to a temp file first
      await tempFile.writeAsBytes(bytes, flush: true);

      // Close the Drift connection before swapping the file
      await AppDatabase.instance.close();

      // Replace local DB with downloaded file
      await tempFile.copy(dbFile.path);
      await tempFile.delete();

      // Delete stale WAL/SHM sidecar files if present
      final walFile = File('${dir.path}/memoix.db-wal');
      final shmFile = File('${dir.path}/memoix.db-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // Reset singleton and reinitialize with a fresh executor
      AppDatabase.resetInstance();
      await MemoixDatabase.initialize();

      // Invalidate providers so all UI rebuilds against the new database
      _ref.invalidate(databaseProvider);
      _ref.invalidate(recipeRepositoryProvider);
      _ref.invalidate(allRecipesProvider);
      _ref.invalidate(weeklyPlanProvider);

      await _setLastSyncTime(DateTime.now());
      _pullFailed = false;

      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;

      if (!silent) {
        MemoixSnackBar.showSuccess('Database synced');
      }

      return const PullResult();
    } catch (e) {
      _pullFailed = true;
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      MemoixSnackBar.showPersistentWithCopy('Pull failed: $e');
      debugPrint('PersonalStorageService.pull error: $e');
      return PullResult.failed(e);
    } finally {
      _isPulling = false;
    }
  }

  // ============ HELPERS ============

  /// Get last sync timestamp from preferences
  Future<DateTime?> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_PrefKeys.lastSyncTime);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Store last sync timestamp
  Future<void> _setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.lastSyncTime, time.toUtc().toIso8601String());
    
    // Also update the active repository's lastSynced field
    final manager = SharedStorageManager();
    final activeRepo = await manager.getActiveRepository();
    if (activeRepo != null) {
      await manager.updateLastSynced(activeRepo.id);
    }
  }

  /// Get device name for meta file
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      }
    } catch (_) {}
    return 'Unknown Device';
  }
}

// ============ PROVIDERS ============

/// Provider for sync status (reactive UI updates)
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

/// Provider for the external storage service
final personalStorageServiceProvider = Provider<PersonalStorageService>((ref) {
  return PersonalStorageService(ref);
});
