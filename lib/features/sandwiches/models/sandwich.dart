import 'package:isar/isar.dart';

part 'sandwich.g.dart';

/// Source of the sandwich
enum SandwichSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own sandwiches
  imported, // Shared with the user
}

@collection
class Sandwich {
  Id id = Isar.autoIncrement;

  /// Unique identifier for sharing and syncing
  @Index(unique: true, replace: true)
  late String uuid;

  /// Sandwich name (e.g., "Bourbon Street", "Cuban")
  @Index(type: IndexType.value)
  late String name;

  /// Bread type (e.g., "Sourdough", "Ciabatta", "Hoagie Roll")
  String bread = '';

  /// List of proteins (e.g., "Blackened Chicken", "Bacon", "Turkey")
  List<String> proteins = [];

  /// List of vegetables (e.g., "Red Onion", "Lettuce", "Tomato")
  List<String> vegetables = [];

  /// List of cheeses (e.g., "Pepper Jack", "Swiss", "Provolone")
  List<String> cheeses = [];

  /// List of condiments (e.g., "Spicy Mayonnaise", "Mustard", "Aioli")
  List<String> condiments = [];

  /// Notes for special instructions (e.g., "Toast bread lightly", "Grill veggies")
  String? notes;

  /// Image URL or local path
  String? imageUrl;

  /// Where this sandwich came from
  @Enumerated(EnumType.name)
  SandwichSource source = SandwichSource.personal;

  /// Whether this is a favourite
  bool isFavorite = false;

  /// How many times this has been made
  int cookCount = 0;

  /// User rating (1-5 stars, 0 = unrated)
  int rating = 0;

  /// Custom tags for additional categorization
  List<String> tags = [];

  /// When the sandwich was created
  DateTime createdAt = DateTime.now();

  /// When the sandwich was last modified
  DateTime updatedAt = DateTime.now();

  /// Version for sync conflict resolution
  int version = 1;

  Sandwich();

  /// Create a new sandwich with required fields
  Sandwich.create({
    required this.uuid,
    required this.name,
    this.bread = '',
    this.proteins = const [],
    this.vegetables = const [],
    this.cheeses = const [],
    this.condiments = const [],
    this.notes,
    this.imageUrl,
    this.source = SandwichSource.personal,
    this.isFavorite = false,
    this.rating = 0,
    this.tags = const [],
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Get the first image (for cards/thumbnails)
  String? getFirstImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl;
    }
    return null;
  }

  /// Create from JSON (for GitHub import)
  factory Sandwich.fromJson(Map<String, dynamic> json) {
    final sandwich = Sandwich()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..bread = json['bread'] as String? ?? ''
      ..proteins = (json['proteins'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..vegetables = (json['vegetables'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..cheeses = (json['cheeses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..condiments = (json['condiments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..notes = json['notes'] as String?
      ..imageUrl = json['imageUrl'] as String?
      ..source = SandwichSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => SandwichSource.memoix,
      )
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..cookCount = json['cookCount'] as int? ?? 0
      ..rating = json['rating'] as int? ?? 0
      ..tags =
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              []
      ..version = json['version'] as int? ?? 1;

    if (json['createdAt'] != null) {
      sandwich.createdAt = DateTime.parse(json['createdAt'] as String);
    }
    if (json['updatedAt'] != null) {
      sandwich.updatedAt = DateTime.parse(json['updatedAt'] as String);
    }

    return sandwich;
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'bread': bread,
      'proteins': proteins,
      'vegetables': vegetables,
      'cheeses': cheeses,
      'condiments': condiments,
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
      'bread': bread,
      'proteins': proteins,
      'vegetables': vegetables,
      'cheeses': cheeses,
      'condiments': condiments,
      'notes': notes,
      'imageUrl': imageUrl,
      'tags': tags,
      'version': version,
    };
  }
}
