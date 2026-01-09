// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drive_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DriveRepository _$DriveRepositoryFromJson(Map<String, dynamic> json) =>
    DriveRepository(
      id: json['id'] as String,
      name: json['name'] as String,
      folderId: json['folderId'] as String,
      isActive: json['isActive'] as bool? ?? false,
      isPendingVerification: json['isPendingVerification'] as bool? ?? false,
      accessDenied: json['accessDenied'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastVerified: json['lastVerified'] == null
          ? null
          : DateTime.parse(json['lastVerified'] as String),
      lastSynced: json['lastSynced'] == null
          ? null
          : DateTime.parse(json['lastSynced'] as String),
      provider: $enumDecodeNullable(_$StorageProviderEnumMap, json['provider']) ??
          StorageProvider.googleDrive,
    );

Map<String, dynamic> _$DriveRepositoryToJson(DriveRepository instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'folderId': instance.folderId,
      'isActive': instance.isActive,
      'isPendingVerification': instance.isPendingVerification,
      'accessDenied': instance.accessDenied,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastVerified': instance.lastVerified?.toIso8601String(),
      'lastSynced': instance.lastSynced?.toIso8601String(),
      'provider': _$StorageProviderEnumMap[instance.provider]!,
    };

const _$StorageProviderEnumMap = {
  StorageProvider.googleDrive: 'googleDrive',
  StorageProvider.oneDrive: 'oneDrive',
};
