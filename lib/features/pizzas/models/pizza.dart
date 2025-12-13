import 'package:isar/isar.dart';

part 'pizza.g.dart';

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

@collection
class Pizza {
  Id id = Isar.autoIncrement;

  /// Unique identifier for sharing and syncing
  @Index(unique: true, replace: true)
  late String uuid;

  /// Pizza name (e.g., "Margherita", "BBQ Chicken")
  @Index(type: IndexType.value)
  late String name;

  /// Base sauce type
  @Enumerated(EnumType.name)
  PizzaBase base = PizzaBase.marinara;

  /// List of cheeses (e.g., "Mozzarella", "Parmesan", "Goat Cheese")
  List<String> cheeses = [];

  /// List of toppings (e.g., "Pepperoni", "Mushrooms", "Basil")
  List<String> toppings = [];

  /// Notes for special instructions (e.g., "Add sundried tomatoes last minute")
  String? notes;

  /// Image URL or local path
  String? imageUrl;

  /// Where this pizza came from
  @Enumerated(EnumType.name)
  PizzaSource source = PizzaSource.personal;

  /// Whether this is a favourite
  bool isFavorite = false;

  /// How many times this has been cooked
  int cookCount = 0;

  /// User rating (1-5 stars, 0 = unrated)
  int rating = 0;

  /// Custom tags for additional categorization
  List<String> tags = [];

  /// When the pizza was created
  DateTime createdAt = DateTime.now();

  /// When the pizza was last modified
  DateTime updatedAt = DateTime.now();

  /// Version for sync conflict resolution
  int version = 1;

  Pizza();

  /// Create a new pizza with required fields
  Pizza.create({
    required this.uuid,
    required this.name,
    this.base = PizzaBase.marinara,
    this.cheeses = const [],
    this.toppings = const [],
    this.notes,
    this.imageUrl,
    this.source = PizzaSource.personal,
    this.isFavorite = false,
    this.rating = 0,
    this.tags = const [],
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Create from JSON (for GitHub import)
  factory Pizza.fromJson(Map<String, dynamic> json) {
    final pizza = Pizza()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..base = PizzaBaseExtension.fromString(json['base'] as String?)
      ..cheeses = (json['cheeses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..toppings = (json['toppings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..notes = json['notes'] as String?
      ..imageUrl = json['imageUrl'] as String?
      ..source = PizzaSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => PizzaSource.memoix,
      )
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..cookCount = json['cookCount'] as int? ?? 0
      ..rating = json['rating'] as int? ?? 0
      ..tags =
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              []
      ..version = json['version'] as int? ?? 1;

    if (json['createdAt'] != null) {
      pizza.createdAt = DateTime.parse(json['createdAt'] as String);
    }
    if (json['updatedAt'] != null) {
      pizza.updatedAt = DateTime.parse(json['updatedAt'] as String);
    }

    return pizza;
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'base': base.name,
      'cheeses': cheeses,
      'toppings': toppings,
      'notes': notes,
      'imageUrl': imageUrl,
      'source': source.name,
      'isFavorite': isFavorite,
      'cookCount': cookCount,
      'rating': rating,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'base': base.name,
      'cheeses': cheeses,
      'toppings': toppings,
      'notes': notes,
      'imageUrl': imageUrl,
      'tags': tags,
      'version': version,
    };
  }
}
