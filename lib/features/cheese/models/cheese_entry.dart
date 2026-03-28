
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
    uuid: json['uuid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    country: json['country'] as String?,
    milk: json['milk'] as String?,
    texture: json['texture'] as String?,
    type: json['type'] as String?,
    buy: json['buy'] as bool? ?? false,
    flavour: json['flavour'] as String?,
    priceRange: (json['priceRange'] as num?)?.toInt(),
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String? ?? CheeseSource.personal.name,
    isFavorite: json['isFavorite'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.now(),
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
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
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


