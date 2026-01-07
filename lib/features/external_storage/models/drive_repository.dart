import 'package:json_annotation/json_annotation.dart';

part 'drive_repository.g.dart';

/// Represents a Google Drive repository (folder) that stores Memoix data
///
/// Multiple repositories allow users to maintain separate collections
/// (e.g., Personal, Family Shared, Work) that can be shared with others.
@JsonSerializable()
class DriveRepository {
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

  /// Timestamp when this repository was added
  final DateTime createdAt;

  /// Timestamp when this repository was last verified/accessed
  final DateTime? lastVerified;

  const DriveRepository({
    required this.id,
    required this.name,
    required this.folderId,
    this.isActive = false,
    this.isPendingVerification = false,
    required this.createdAt,
    this.lastVerified,
  });

  /// Create a copy with updated fields
  DriveRepository copyWith({
    String? id,
    String? name,
    String? folderId,
    bool? isActive,
    bool? isPendingVerification,
    DateTime? createdAt,
    DateTime? lastVerified,
  }) {
    return DriveRepository(
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      isActive: isActive ?? this.isActive,
      isPendingVerification: isPendingVerification ?? this.isPendingVerification,
      createdAt: createdAt ?? this.createdAt,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  factory DriveRepository.fromJson(Map<String, dynamic> json) =>
      _$DriveRepositoryFromJson(json);

  Map<String, dynamic> toJson() => _$DriveRepositoryToJson(this);
}
