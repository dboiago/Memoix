import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/drive_repository.dart';

/// Manages Google Drive repositories (multiple storage locations)
class RepositoryManager {
  static const _keyRepositories = 'drive_repositories';
  static const _uuid = Uuid();

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
  Future<void> setActiveRepository(String repositoryId) async {
    final repos = await loadRepositories();
    final updated = repos.map((r) {
      return r.copyWith(isActive: r.id == repositoryId);
    }).toList();
    await saveRepositories(updated);
  }

  /// Add a new repository
  Future<DriveRepository> addRepository({
    required String name,
    required String folderId,
    bool setAsActive = false,
    bool isPendingVerification = false,
  }) async {
    final repos = await loadRepositories();
    
    final newRepo = DriveRepository(
      id: _uuid.v4(),
      name: name,
      folderId: folderId,
      isActive: setAsActive,
      isPendingVerification: isPendingVerification,
      createdAt: DateTime.now(),
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

  /// Check if a folder ID already exists in repositories
  Future<bool> folderIdExists(String folderId) async {
    final repos = await loadRepositories();
    return repos.any((r) => r.folderId == folderId);
  }
}
