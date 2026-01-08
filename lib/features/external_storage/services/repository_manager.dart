import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/drive_repository.dart';
import '../providers/one_drive_storage.dart';

/// Manages cloud storage repositories (multiple storage locations)
/// Supports multiple providers (Google Drive, OneDrive, etc.)
class RepositoryManager {
  static const _keyRepositories = 'drive_repositories';
  static const _uuid = Uuid();

  /// Whether a repository switch is currently in progress
  bool _isSwitching = false;

  /// Get whether a switch operation is in progress
  bool get isSwitching => _isSwitching;

  /// Load all saved repositories
  Future<List<DriveRepository>> loadRepositories() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyRepositories);
    
    if (json == null) return [];
    
    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => DriveRepository.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Save repositories list
  Future<void> saveRepositories(List<DriveRepository> repositories) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(repositories.map((r) => r.toJson()).toList());
    await prefs.setString(_keyRepositories, json);
  }

  /// Get the currently active repository
  Future<DriveRepository?> getActiveRepository() async {
    final repos = await loadRepositories();
    try {
      return repos.firstWhere((r) => r.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Set a repository as active (deactivates all others)
  /// 
  /// When switching repositories, the provider type is checked to determine
  /// which cloud storage implementation to use.
  /// 
  /// This method ensures strict ordering:
  /// 1. Set switching flag
  /// 2. Initialize provider fully
  /// 3. Update repository state
  /// 4. Clear switching flag
  Future<void> setActiveRepository(String repositoryId) async {
    if (_isSwitching) {
      throw Exception('Repository switch already in progress');
    }

    _isSwitching = true;
    
    final repos = await loadRepositories();
    
    // Store the current active repo for rollback if switch fails
    DriveRepository? previousActiveRepo;
    try {
      previousActiveRepo = repos.firstWhere((r) => r.isActive);
    } catch (_) {
      // No previous active repo
    }
    
    // Get the target repository before updating state
    final activeRepo = repos.firstWhere((r) => r.id == repositoryId);
    
    // Initialize appropriate provider based on activeRepo.provider
    // This MUST complete before updating repository state
    try {
      switch (activeRepo.provider) {
        case StorageProvider.googleDrive:
          // GoogleDriveStorage is already initialized via Riverpod provider
          // The UI layer handles switching via googleDriveStorageProvider
          debugPrint('RepositoryManager: Initializing Google Drive repository: ${activeRepo.name}');
          // Wait a brief moment to ensure UI is ready
          await Future.delayed(const Duration(milliseconds: 100));
          break;
          
        case StorageProvider.oneDrive:
          debugPrint('RepositoryManager: Initializing OneDrive repository: ${activeRepo.name}');
          
          // Initialize OneDrive storage and wait for it to be ready
          final oneDriveStorage = OneDriveStorage();
          await oneDriveStorage.init();
          
          // Check if connected
          if (oneDriveStorage.isConnected) {
            // Switch to the repository folder and wait for completion
            await oneDriveStorage.switchRepository(
              activeRepo.folderId,
              activeRepo.name,
            );
            
            debugPrint('RepositoryManager: OneDrive repository initialized and ready');
          } else {
            _isSwitching = false;
            debugPrint('RepositoryManager: OneDrive not connected, user needs to sign in');
            throw Exception('OneDrive not connected. Please sign in first.');
          }
          break;
      }
      
      // Provider is now fully initialized - safe to update repository state
      final updated = repos.map((r) {
        return r.copyWith(isActive: r.id == repositoryId);
      }).toList();
      await saveRepositories(updated);
      
      debugPrint('RepositoryManager: Successfully switched to ${activeRepo.name}');
      
    } catch (e) {
      debugPrint('RepositoryManager: Error switching to repository: $e');
      
      // Rollback: Restore previous active repository
      if (previousActiveRepo != null) {
        final rolledBack = repos.map((r) {
          return r.copyWith(isActive: r.id == previousActiveRepo!.id);
        }).toList();
        await saveRepositories(rolledBack);
        debugPrint('RepositoryManager: Rolled back to previous repository: ${previousActiveRepo.name}');
      }
      
      _isSwitching = false;
      rethrow;
    } finally {
      _isSwitching = false;
    }
  }

  /// Add a new repository
  Future<DriveRepository> addRepository({
    required String name,
    required String folderId,
    bool setAsActive = false,
    bool isPendingVerification = false,
    StorageProvider provider = StorageProvider.googleDrive,
  }) async {
    final repos = await loadRepositories();
    
    final newRepo = DriveRepository(
      id: _uuid.v4(),
      name: name,
      folderId: folderId,
      isActive: setAsActive,
      isPendingVerification: isPendingVerification,
      createdAt: DateTime.now(),
      provider: provider,
    );

    // If setting as active, deactivate all others
    if (setAsActive) {
      final updated = repos.map((r) => r.copyWith(isActive: false)).toList();
      updated.add(newRepo);
      await saveRepositories(updated);
    } else {
      repos.add(newRepo);
      await saveRepositories(repos);
    }

    return newRepo;
  }

  /// Remove a repository
  Future<void> removeRepository(String repositoryId) async {
    final repos = await loadRepositories();
    repos.removeWhere((r) => r.id == repositoryId);
    await saveRepositories(repos);
  }

  /// Update repository verification status
  Future<void> markAsVerified(String repositoryId) async {
    final repos = await loadRepositories();
    final updated = repos.map((r) {
      if (r.id == repositoryId) {
        return r.copyWith(
          isPendingVerification: false,
          lastVerified: DateTime.now(),
        );
      }
      return r;
    }).toList();
    await saveRepositories(updated);
  }

  /// Mark repository as access denied (verification failed)
  /// 
  /// This keeps isPendingVerification = true and sets accessDenied = true,
  /// allowing users to see they need permission and retry later.
  Future<void> markAsAccessDenied(String repositoryId) async {
    final repos = await loadRepositories();
    final updated = repos.map((r) {
      if (r.id == repositoryId) {
        return r.copyWith(
          isPendingVerification: true,
          accessDenied: true,
        );
      }
      return r;
    }).toList();
    await saveRepositories(updated);
  }

  /// Get all repositories with pending verification
  Future<List<DriveRepository>> getPendingRepositories() async {
    final repos = await loadRepositories();
    return repos.where((r) => r.isPendingVerification).toList();
  }

  /// Check if a folder ID already exists in repositories
  Future<bool> folderIdExists(String folderId) async {
    final repos = await loadRepositories();
    return repos.any((r) => r.folderId == folderId);
  }

  /// Update lastSynced timestamp for a repository
  Future<void> updateLastSynced(String repositoryId) async {
    final repos = await loadRepositories();
    final updated = repos.map((r) {
      if (r.id == repositoryId) {
        return r.copyWith(lastSynced: DateTime.now());
      }
      return r;
    }).toList();
    await saveRepositories(updated);
  }
}
