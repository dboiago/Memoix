
import 'dart:convert';
import '../../../core/database/app_database.dart';

/// Source of the pizza
enum PizzaSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own pizzas
  imported, // Shared with the user
}

/// Available pizza base sauces
enum PizzaBase {
  marinara,
  oil,
  pesto,
  cream,
  bbq,
  buffalo,
  alfredo,
  garlic,
  none,
}

extension PizzaBaseExtension on PizzaBase {
  /// Display name for the base
  String get displayName {
    switch (this) {
      case PizzaBase.marinara:
        return 'Marinara';
      case PizzaBase.oil:
        return 'Oil';
      case PizzaBase.pesto:
        return 'Pesto';
      case PizzaBase.cream:
        return 'Cream';
      case PizzaBase.bbq:
        return 'BBQ';
      case PizzaBase.buffalo:
        return 'Buffalo';
      case PizzaBase.alfredo:
        return 'Alfredo';
      case PizzaBase.garlic:
        return 'Garlic Butter';
      case PizzaBase.none:
        return 'No Sauce';
    }
  }

  /// Parse base from string (for JSON import)
  static PizzaBase fromString(String? value) {
    if (value == null || value.isEmpty) return PizzaBase.marinara;
    final lower = value.toLowerCase().trim();
    
    // Handle common variations
    if (lower.contains('marinara') || lower.contains('tomato') || lower == 'red') return PizzaBase.marinara;
    if (lower.contains('oil') || lower == 'evoo' || lower == 'olive') return PizzaBase.oil;
    if (lower.contains('pesto')) return PizzaBase.pesto;
    if (lower.contains('cream') || lower == 'white') return PizzaBase.cream;
    if (lower.contains('bbq') || lower.contains('barbeque') || lower.contains('barbecue')) return PizzaBase.bbq;
    if (lower.contains('buffalo') || lower.contains('hot sauce')) return PizzaBase.buffalo;
    if (lower.contains('alfredo')) return PizzaBase.alfredo;
    if (lower.contains('garlic')) return PizzaBase.garlic;
    if (lower == 'none' || lower == 'no sauce') return PizzaBase.none;
    
    return PizzaBase.marinara; // Default
  }
}

/// Decode a Pizza from a JSON map (for backup import).
Pizza pizzaFromJson(Map<String, dynamic> json) {
  String encodeList(dynamic v) =>
      v is List ? jsonEncode(v) : (v as String? ?? '[]');
  return Pizza(
    id: (json['id'] as num?)?.toInt() ?? 0,
    uuid: json['uuid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    base: json['base'] as String? ?? PizzaBase.marinara.name,
    cheeses: encodeList(json['cheeses']),
    proteins: encodeList(json['proteins']),
    vegetables: encodeList(json['vegetables']),
    notes: json['notes'] as String?,
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String? ?? PizzaSource.personal.name,
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

extension PizzaX on Pizza {
  List<String> get cheesesList =>
      (jsonDecode(cheeses) as List).cast<String>();
  List<String> get proteinsList =>
      (jsonDecode(proteins) as List).cast<String>();
  List<String> get vegetablesList =>
      (jsonDecode(vegetables) as List).cast<String>();

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'base': base,
        'cheeses': jsonDecode(cheeses),
        'proteins': jsonDecode(proteins),
        'vegetables': jsonDecode(vegetables),
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
        'base': base,
        'cheeses': jsonDecode(cheeses),
        'proteins': jsonDecode(proteins),
        'vegetables': jsonDecode(vegetables),
        'notes': notes,
        'imageUrl': imageUrl,
      };
}


