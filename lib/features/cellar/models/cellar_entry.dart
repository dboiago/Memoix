
import 'dart:convert';
import '../../../core/database/app_database.dart';

/// Source of the cellar entry
enum CellarSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own entries
  imported, // Shared with the user
}

/// Decode a CellarEntry from a JSON map (for backup import).
CellarEntry cellarEntryFromJson(Map<String, dynamic> json) {
  return CellarEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    uuid: json['uuid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    producer: json['producer'] as String?,
    category: json['category'] as String?,
    buy: json['buy'] as bool? ?? false,
    tastingNotes: json['tastingNotes'] as String?,
    abv: json['abv'] as String?,
    ageVintage: json['ageVintage'] as String?,
    priceRange: (json['priceRange'] as num?)?.toInt(),
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String? ?? CellarSource.personal.name,
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

extension CellarEntryX on CellarEntry {
  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'producer': producer,
        'category': category,
        'buy': buy,
        'tastingNotes': tastingNotes,
        'abv': abv,
        'ageVintage': ageVintage,
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
        'producer': producer,
        'category': category,
        'tastingNotes': tastingNotes,
        'abv': abv,
        'ageVintage': ageVintage,
        'priceRange': priceRange,
        'imageUrl': imageUrl,
      };
}


