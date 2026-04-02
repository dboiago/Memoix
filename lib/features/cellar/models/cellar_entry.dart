
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
    uuid: json['uuid']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    producer: json['producer']?.toString(),
    category: json['category']?.toString(),
    buy: json['buy'] as bool? ?? false,
    tastingNotes: json['tastingNotes']?.toString(),
    abv: json['abv']?.toString(),
    ageVintage: json['ageVintage']?.toString(),
    priceRange: (json['priceRange'] as num?)?.toInt(),
    imageUrl: json['imageUrl']?.toString(),
    source: json['source']?.toString() ?? CellarSource.personal.name,
    isFavorite: json['isFavorite'] as bool? ?? false,
    createdAt: json['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : json['createdAt'] != null
            ? DateTime.parse(json['createdAt'].toString())
            : DateTime.now(),
    updatedAt: json['updatedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
        : json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'].toString())
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


