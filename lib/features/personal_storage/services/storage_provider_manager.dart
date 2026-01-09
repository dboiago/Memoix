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
/// 1. Disconnects any active Personal Storage provider
/// 2. Deactivates any active Shared Storage location
/// 3. Disconnects the cloud provider used by that Shared Storage
class StorageProviderManager {
  /// Disconnect all storage providers and deactivate all storage locations
  /// 
  /// Call this before connecting to ANY new provider to ensure mutual exclusivity
  /// 
  /// [ref] - WidgetRef or ProviderRef to access providers
  static Future<void> disconnectAll(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Disconnect Personal Storage provider
    final personalProviderId = prefs.getString('personal_storage_provider_id');
    if (personalProviderId != null) {
      await _disconnectProvider(personalProviderId, ref);
    }
    
    // Clear Personal Storage preferences
    await prefs.remove('personal_storage_provider_id');
    await prefs.remove('personal_storage_path');
    
    // 2. Deactivate and disconnect Shared Storage
    final sharedManager = SharedStorageManager();
    final storageLocations = await sharedManager.loadRepositories();
    final activeLocation = storageLocations.where((r) => r.isActive).firstOrNull;
    
    if (activeLocation != null) {
      // Disconnect the provider used by Shared Storage
      await _disconnectProvider(activeLocation.provider.id, ref);
      
      // Deactivate all shared storage locations
      final updated = storageLocations.map((r) => r.copyWith(isActive: false)).toList();
      await sharedManager.saveRepositories(updated);
    }
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
