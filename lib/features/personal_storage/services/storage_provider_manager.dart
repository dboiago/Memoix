import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/storage_location.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';
import 'shared_storage_manager.dart';

/// Centralized manager for storage provider connections
/// 
/// Ensures only ONE provider is connected at a time across:
/// - Personal Storage (Google Drive, OneDrive, etc.)
/// - Shared Storage (Google Drive, OneDrive, etc.)
/// 
/// When connecting to any provider, this manager:
/// 1. Disconnects competing providers (not the one being connected)
/// 2. Deactivates competing storage locations
class StorageProviderManager {
  /// Disconnect all storage providers EXCEPT the one being activated
  /// 
  /// Use this when activating Shared Storage - it disconnects Personal Storage
  /// but leaves the Shared Storage provider connected.
  /// 
  /// [ref] - WidgetRef or ProviderRef to access providers
  /// [exceptProvider] - Provider to keep connected (optional)
  static Future<void> disconnectAllExcept(WidgetRef ref, {StorageProvider? exceptProvider}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Disconnect Personal Storage provider (if different from the one we're activating)
    final personalProviderId = prefs.getString('personal_storage_provider_id');
    if (personalProviderId != null && personalProviderId != exceptProvider?.id) {
      await _disconnectProvider(personalProviderId, ref);
    }
    
    // Clear Personal Storage preferences
    await prefs.remove('personal_storage_provider_id');
    await prefs.remove('personal_storage_path');
    
    // 2. Deactivate Shared Storage (and disconnect its provider if different)
    final sharedManager = SharedStorageManager();
    final storageLocations = await sharedManager.loadRepositories();
    final activeLocation = storageLocations.where((r) => r.isActive).firstOrNull;
    
    if (activeLocation != null) {
      // Only disconnect if it's a different provider than the one we're activating
      if (exceptProvider == null || activeLocation.provider != exceptProvider) {
        await _disconnectProvider(activeLocation.provider.id, ref);
      }
      
      // Deactivate all shared storage locations
      final updated = storageLocations.map((r) => r.copyWith(isActive: false)).toList();
      await sharedManager.saveRepositories(updated);
    }
  }
  
  /// Disconnect all storage providers and deactivate all storage locations
  /// 
  /// Use this when connecting to Personal Storage - ensures nothing else is active
  /// 
  /// [ref] - WidgetRef or ProviderRef to access providers
  static Future<void> disconnectAll(WidgetRef ref) async {
    await disconnectAllExcept(ref, exceptProvider: null);
  }
  
  /// Disconnect a specific provider by ID
  /// 
  /// [providerId] - Provider identifier ('google_drive', 'onedrive', etc.)
  /// [ref] - WidgetRef or ProviderRef to access providers
  static Future<void> _disconnectProvider(String providerId, WidgetRef ref) async {
    switch (providerId) {
      case 'google_drive':
        final googleStorage = ref.read(googleDriveStorageProvider);
        if (googleStorage.isConnected) {
          await googleStorage.disconnect();
        }
        break;
        
      case 'onedrive':
        final oneDriveStorage = OneDriveStorage();
        await oneDriveStorage.init();
        if (oneDriveStorage.isConnected) {
          await oneDriveStorage.signOut();
        }
        break;
        
      // Add future providers here (iCloud, Dropbox, etc.)
      default:
        // Unknown provider - skip
        break;
    }
  }
}
