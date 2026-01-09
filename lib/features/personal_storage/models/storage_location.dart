import 'package:json_annotation/json_annotation.dart';

part 'storage_location.g.dart';

/// Cloud storage provider type
enum StorageProvider {
  googleDrive,
  oneDrive,
}

/// Extension for StorageProvider display names
extension StorageProviderDisplay on StorageProvider {
  String get displayName {
    switch (this) {
      case StorageProvider.googleDrive:
        return 'Google Drive';
      case StorageProvider.oneDrive:
        return 'Microsoft OneDrive';
    }
  }
}

/// Represents a Google Drive repository (folder) that stores Memoix data
///
/// Multiple repositories allow users to maintain separate collections
/// (e.g., Personal, Family Shared, Work) that can be shared with others.
@JsonSerializable()
class StorageLocation {
  /// Unique identifier for this repository configuration
  final String id;

  /// User-friendly name for the repository
  final String name;

  /// Google Drive folder ID where data is stored
  final String folderId;

  /// Whether this is the currently active repository
  final bool isActive;

  /// Whether this repository was provisionally added while offline
  /// (access not yet verified)
  final bool isPendingVerification;

  /// Whether access verification failed (403 Forbidden)
  /// User needs to request permission from repository owner
  final bool accessDenied;

  /// Timestamp when this repository was added
  final DateTime createdAt;

  /// Timestamp when this repository was last verified/accessed
  final DateTime? lastVerified;

  /// Timestamp when this repository was last synced (push or pull)
  final DateTime? lastSynced;

  /// Cloud storage provider for this repository
  final StorageProvider provider;

  const StorageLocation({
    required this.id,
    required this.name,
    required this.folderId,
    this.isActive = false,
    this.isPendingVerification = false,
    this.accessDenied = false,
    required this.createdAt,
    this.lastVerified,
    this.lastSynced,
    this.provider = StorageProvider.googleDrive,  // Default for backward compatibility
  });

  /// Create a copy with updated fields
  StorageLocation copyWith({
    String? id,
    String? name,
    String? folderId,
    bool? isActive,
    bool? isPendingVerification,
    bool? accessDenied,
    DateTime? createdAt,
    DateTime? lastVerified,
    DateTime? lastSynced,    StorageProvider? provider,  }) {
    return StorageLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      isActive: isActive ?? this.isActive,
      isPendingVerification: isPendingVerification ?? this.isPendingVerification,
      accessDenied: accessDenied ?? this.accessDenied,
      createdAt: createdAt ?? this.createdAt,
      lastVerified: lastVerified ?? this.lastVerified,
      lastSynced: lastSynced ?? this.lastSynced,
      provider: provider ?? this.provider,
    );
  }

  factory StorageLocation.fromJson(Map<String, dynamic> json) =>
      _$StorageLocationFromJson(json);

  Map<String, dynamic> toJson() => _$StorageLocationToJson(this);
}
