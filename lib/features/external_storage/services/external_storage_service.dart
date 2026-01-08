import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../cellar/models/cellar_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../models/drive_repository.dart';
import '../models/merge_result.dart';
import '../models/recipe_bundle.dart';
import '../models/storage_meta.dart';
import '../models/sync_mode.dart';
import '../models/sync_status.dart';
import '../providers/external_storage_provider.dart';
import '../providers/google_drive_storage.dart';

/// Preference keys for external storage settings
class _PrefKeys {
  static const lastSyncTime = 'external_storage_last_sync';
  static const syncMode = 'external_storage_sync_mode';
  static const connectedProviderId = 'external_storage_provider_id';
  static const connectedPath = 'external_storage_path';
}

/// Core service for external storage sync operations
/// 
/// Handles push/pull logic, merge strategy, and app lifecycle integration.
/// See EXTERNAL_STORAGE.md Section 8 for architecture details.
class ExternalStorageService {
  final Ref _ref;
  ExternalStorageProvider? _provider;
  
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

  /// Minimum time between automatic syncs (5 minutes)
  static const _syncCooldown = Duration(minutes: 5);
  
  /// Debounce delay for batching recipe saves (5 seconds)
  static const _pushDebounceDelay = Duration(seconds: 5);
  
  /// Maximum retry attempts for failed operations
  static const _maxRetries = 3;
  
  /// Base delay for exponential backoff (doubles each retry)
  static const _baseRetryDelay = Duration(seconds: 1);

  ExternalStorageService(this._ref);

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
        debugPrint('ExternalStorageService: Unknown provider ID: $providerId');
        _isInitialized = true;
        return;
      }
      
      // Initialize the provider (handles silent sign-in)
      await provider.initialize();
      
      if (provider.isConnected) {
        _provider = provider;
        debugPrint('ExternalStorageService: Restored connection to ${provider.name}');
        
        // If there were pending changes queued before initialization, trigger push
        if (_hasPendingChanges) {
          final isAuto = await isAutomaticMode;
          if (isAuto) {
            debugPrint('ExternalStorageService: Flushing pending changes after init');
            push(silent: true);
          }
        }
      } else {
        // Silent sign-in failed (token expired/revoked)
        // Clear stored state so user can reconnect
        await prefs.remove(_PrefKeys.connectedProviderId);
        debugPrint('ExternalStorageService: Failed to restore ${provider.name} connection');
      }
    } catch (e) {
      debugPrint('ExternalStorageService: Provider restoration error: $e');
      // Don't throw - just leave provider as null, user can reconnect manually
    }
    
    _isInitialized = true;
  }
  
  /// Create a provider instance by ID
  ExternalStorageProvider? _createProvider(String providerId) {
    switch (providerId) {
      case 'google_drive':
        return GoogleDriveStorage();
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
          'ExternalStorageService: $operationName attempt $attempt/$_maxRetries failed: $e',
        );
        
        if (attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          final delay = _baseRetryDelay * math.pow(2, attempt - 1).toInt();
          debugPrint('ExternalStorageService: Retrying in ${delay.inSeconds}s...');
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
  ExternalStorageProvider? get provider => _provider;

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
  Future<void> setProvider(ExternalStorageProvider provider) async {
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
    await prefs.remove(_PrefKeys.lastSyncTime);
    
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
    if (!_isInitialized || !isConnected) return;
    
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
    
    if (_hasPendingChanges) {
      await push(silent: true);
    }
  }

  // ============ PUSH OPERATION ============

  /// Push local data to remote storage
  /// 
  /// [silent] - If true, show minimal UI feedback (for automatic syncs)
  /// Implements retry with exponential backoff per EXTERNAL_STORAGE.md Section 10.
  Future<void> push({bool silent = false}) async {
    if (_provider == null) {
      if (!silent) MemoixSnackBar.showError('No storage provider connected');
      return;
    }
    
    if (_isPushing) return; // Prevent concurrent pushes
    _isPushing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pushing;

    try {
      // Create bundle from all local data
      final bundle = await _createBundle();
      
      // Push to remote with retry logic
      await _withRetry(
        () async {
          await _provider!.push(bundle);
          
          // Update meta file
          final meta = StorageMeta.create(
            deviceName: await _getDeviceName(),
            domains: bundle.domainCounts,
          );
          await _provider!.updateMeta(meta);
        },
        operationName: 'push',
      );
      
      // Update last sync time in preferences
      final syncTime = DateTime.now();
      await _setLastSyncTime(syncTime);
      _hasPendingChanges = false;
      
      // Update lastSynced timestamp in active repository
      final prefs = await SharedPreferences.getInstance();
      final repositoriesJson = prefs.getString('drive_repositories');
      if (repositoriesJson != null) {
        final List<dynamic> list = jsonDecode(repositoriesJson);
        final repositories = list.map((item) => 
          DriveRepository.fromJson(item as Map<String, dynamic>)
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
        MemoixSnackBar.showSuccess('Pushed ${bundle.totalCount} recipes');
      }
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      if (!silent) {
        MemoixSnackBar.showError('Push failed: $e');
      }
      debugPrint('ExternalStorageService.push error: $e');
    } finally {
      _isPushing = false;
    }
  }

  // ============ PULL OPERATION ============

  /// Pull remote data and merge into local database
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
            // Remote hasn't changed since last sync
            _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
            if (!silent) {
              MemoixSnackBar.show('Already up to date');
            }
            return PullResult.skipped();
          }
        }
      }

      // Download bundle with retry logic
      final bundle = await _withRetry(
        () => _provider!.pull(),
        operationName: 'pull',
      );
      if (bundle == null) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
        if (!silent) {
          MemoixSnackBar.show('No recipes found in storage');
        }
        return PullResult.skipped();
      }

      // Merge into local database
      final mergeResult = await _mergeBundle(bundle);
      
      // Update last sync time
      await _setLastSyncTime(DateTime.now());
      
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;

      // Only show feedback if not silent AND there were actual changes
      if (!silent && mergeResult.hasChanges) {
        MemoixSnackBar.show(mergeResult.summaryMessage);
      } else if (!silent && !mergeResult.hasChanges) {
        // Silent sync when no changes detected
        debugPrint('ExternalStorageService: Sync complete, no changes detected');
      }
      
      return PullResult.fromMerge(mergeResult, remoteCount: bundle.totalCount);
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      if (!silent) {
        MemoixSnackBar.showError('Pull failed: $e');
      }
      debugPrint('ExternalStorageService.pull error: $e');
      return PullResult.failed(e);
    } finally {
      _isPulling = false;
    }
  }

  // ============ BUNDLE CREATION ============

  /// Create a RecipeBundle from all local data
  Future<RecipeBundle> _createBundle() async {
    final db = _ref.read(databaseProvider);
    
    // Fetch all data from each domain
    final recipes = await db.recipes.where().findAll();
    final pizzas = await db.pizzas.where().findAll();
    final sandwiches = await db.sandwichs.where().findAll();
    final cheeses = await db.cheeseEntrys.where().findAll();
    final cellar = await db.cellarEntrys.where().findAll();
    final smoking = await db.smokingRecipes.where().findAll();
    final modernist = await db.modernistRecipes.where().findAll();

    return RecipeBundle(
      recipes: recipes,
      pizzas: pizzas,
      sandwiches: sandwiches,
      cheeses: cheeses,
      cellar: cellar,
      smoking: smoking,
      modernist: modernist,
      metadata: BundleMetadata.create(
        deviceName: await _getDeviceName(),
      ),
    );
  }

  // ============ MERGE LOGIC ============

  /// Merge a pulled bundle into local database
  /// 
  /// Strategy: Last-Write-Wins with Merge
  /// - Remote-only items: Add to local
  /// - Local-only items: Keep (push will upload them)
  /// - Both exist: Keep newer based on updatedAt timestamp
  Future<MergeResult> _mergeBundle(RecipeBundle bundle) async {
    final db = _ref.read(databaseProvider);
    
    var result = const MergeResult();

    // Merge recipes
    result = result + await _mergeRecipes(db, bundle.recipes);
    
    // Merge pizzas
    result = result + await _mergePizzas(db, bundle.pizzas);
    
    // Merge sandwiches
    result = result + await _mergeSandwiches(db, bundle.sandwiches);
    
    // Merge cheeses
    result = result + await _mergeCheeses(db, bundle.cheeses);
    
    // Merge cellar
    result = result + await _mergeCellar(db, bundle.cellar);
    
    // Merge smoking
    result = result + await _mergeSmoking(db, bundle.smoking);
    
    // Merge modernist
    result = result + await _mergeModernist(db, bundle.modernist);

    return result;
  }

  /// Merge recipes domain
  Future<MergeResult> _mergeRecipes(Isar db, List<Recipe> remoteRecipes) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteRecipes) {
        final existing = await db.recipes
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          // Remote-only: add to local
          await db.recipes.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          // Remote is newer: check if content actually differs
          // Compare JSON size as a quick content check to avoid false positives
          final remoteSize = jsonEncode(remote.toJson()).length;
          final existingSize = jsonEncode(existing.toJson()).length;
          
          if (remoteSize != existingSize) {
            // Content differs: update local
            remote.id = existing.id; // Preserve local ID
            await db.recipes.put(remote);
            updated++;
          } else {
            // Same size, likely identical content: keep local
            unchanged++;
          }
        } else {
          // Local is same or newer: keep local
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge pizzas domain
  Future<MergeResult> _mergePizzas(Isar db, List<Pizza> remotePizzas) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for // Check if content differs by comparing JSON size
          final remoteSize = jsonEncode(remote.toJson()).length;
          final existingSize = jsonEncode(existing.toJson()).length;
          
          if (remoteSize != existingSize) {
            remote.id = existing.id;
            await db.pizzas.put(remote);
            updated++;
          } else {
            unchanged++;
          })
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.pizzas.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.pizzas.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge sandwiches domain
  Future<MergeResult> _mergeSandwiches(Isar db, List<Sandwich> remoteSandwiches) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteSandwiches) {
        final existing = await db.sandwichs
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.sandwichs.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.sandwichs.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge cheeses domain
  Future<MergeResult> _mergeCheeses(Isar db, List<CheeseEntry> remoteCheeses) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteCheeses) {
        final existing = await db.cheeseEntrys
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.cheeseEntrys.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.cheeseEntrys.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge cellar domain
  Future<MergeResult> _mergeCellar(Isar db, List<CellarEntry> remoteCellar) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteCellar) {
        final existing = await db.cellarEntrys
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.cellarEntrys.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.cellarEntrys.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge smoking domain
  Future<MergeResult> _mergeSmoking(Isar db, List<SmokingRecipe> remoteSmoking) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteSmoking) {
        final existing = await db.smokingRecipes
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.smokingRecipes.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.smokingRecipes.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }

  /// Merge modernist domain
  Future<MergeResult> _mergeModernist(Isar db, List<ModernistRecipe> remoteModernist) async {
    int added = 0, updated = 0, unchanged = 0;

    await db.writeTxn(() async {
      for (final remote in remoteModernist) {
        final existing = await db.modernistRecipes
            .filter()
            .uuidEqualTo(remote.uuid)
            .findFirst();

        if (existing == null) {
          await db.modernistRecipes.put(remote);
          added++;
        } else if (remote.updatedAt.isAfter(existing.updatedAt)) {
          remote.id = existing.id;
          await db.modernistRecipes.put(remote);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    return MergeResult(added: added, updated: updated, unchanged: unchanged);
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
    final manager = RepositoryManager();
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
final externalStorageServiceProvider = Provider<ExternalStorageService>((ref) {
  return ExternalStorageService(ref);
});
