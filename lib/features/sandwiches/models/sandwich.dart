
import 'dart:convert';
import '../../../core/database/app_database.dart';

/// Source of the sandwich
enum SandwichSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own sandwiches
  imported, // Shared with the user
}

/// Decode a Sandwich from a JSON map (for backup import).
Sandwich sandwichFromJson(Map<String, dynamic> json) {
  String encodeList(dynamic v) =>
      v is List ? jsonEncode(v) : (v as String? ?? '[]');
  return Sandwich(
    id: (json['id'] as num?)?.toInt() ?? 0,
    uuid: json['uuid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    bread: json['bread'] as String? ?? '',
    proteins: encodeList(json['proteins']),
    vegetables: encodeList(json['vegetables']),
    cheeses: encodeList(json['cheeses']),
    condiments: encodeList(json['condiments']),
    notes: json['notes'] as String?,
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String? ?? SandwichSource.personal.name,
    isFavorite: json['isFavorite'] as bool? ?? false,
    cookCount: (json['cookCount'] as num?)?.toInt() ?? 0,
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    tags: encodeList(json['tags']),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.now(),
    version: (json['version'] as num?)?.toInt() ?? 1,
  );
}

extension SandwichX on Sandwich {
  List<String> get proteinsList =>
      (jsonDecode(proteins) as List).cast<String>();
  List<String> get vegetablesList =>
      (jsonDecode(vegetables) as List).cast<String>();
  List<String> get cheesesList =>
      (jsonDecode(cheeses) as List).cast<String>();
  List<String> get condimentsList =>
      (jsonDecode(condiments) as List).cast<String>();

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'bread': bread,
        'proteins': jsonDecode(proteins),
        'vegetables': jsonDecode(vegetables),
        'cheeses': jsonDecode(cheeses),
        'condiments': jsonDecode(condiments),
        'notes': notes,
        'imageUrl': imageUrl,
        'source': source,
        'isFavorite': isFavorite,
        'cookCount': cookCount,
        'rating': rating,
        'tags': jsonDecode(tags),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'version': version,
      };

  Map<String, dynamic> toShareableJson() => {
        'name': name,
        'bread': bread,
        'proteins': jsonDecode(proteins),
        'vegetables': jsonDecode(vegetables),
        'cheeses': jsonDecode(cheeses),
        'condiments': jsonDecode(condiments),
        'notes': notes,
        'imageUrl': imageUrl,
      };
}


