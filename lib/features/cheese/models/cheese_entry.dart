
import 'dart:convert';
import '../../../core/database/app_database.dart';

/// Source of the cheese entry
enum CheeseSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own entries
  imported, // Shared with the user
}

/// Decode a CheeseEntry from a JSON map (for backup import).
CheeseEntry cheeseEntryFromJson(Map<String, dynamic> json) {
  return CheeseEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    uuid: json['uuid']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    country: json['country']?.toString(),
    milk: json['milk']?.toString(),
    texture: json['texture']?.toString(),
    type: json['type']?.toString(),
    buy: json['buy'] as bool? ?? false,
    flavour: json['flavour']?.toString(),
    priceRange: (json['priceRange'] as num?)?.toInt(),
    imageUrl: json['imageUrl']?.toString(),
    source: json['source']?.toString() ?? CheeseSource.personal.name,
    isFavorite: json['isFavorite'] as bool? ?? false,
    createdAt: json['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int).toUtc()
        : json['createdAt'] != null
            ? DateTime.parse(json['createdAt'].toString()).toUtc()
            : DateTime.now().toUtc(),
    updatedAt: json['updatedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int).toUtc()
        : json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'].toString()).toUtc()
            : DateTime.now().toUtc(),
    version: (json['version'] as num?)?.toInt() ?? 1,
  );
}

extension CheeseEntryX on CheeseEntry {
  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'country': country,
        'milk': milk,
        'texture': texture,
        'type': type,
        'buy': buy,
        'flavour': flavour,
        'priceRange': priceRange,
        'imageUrl': imageUrl,
        'source': source,
        'isFavorite': isFavorite,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
      };

  Map<String, dynamic> toShareableJson() => {
        'name': name,
        'country': country,
        'milk': milk,
        'texture': texture,
        'type': type,
        'flavour': flavour,
        'priceRange': priceRange,
        'imageUrl': imageUrl,
      };
}


