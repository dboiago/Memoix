import 'package:isar/isar.dart';

part 'cellar_entry.g.dart';

/// Source of the cellar entry
enum CellarSource {
  personal, // User's own entries
  imported, // Shared with the user
}

@collection
class CellarEntry {
  Id id = Isar.autoIncrement;

  /// Unique identifier for sharing and syncing
  @Index(unique: true, replace: true)
  late String uuid;

  /// Item name
  @Index(type: IndexType.value)
  late String name;

  /// Producer or origin
  String? producer;

  /// Category (freeform: wine, whiskey, coffee, tea, etc.)
  String? category;

  /// Would buy again
  bool buy = false;

  /// Tasting notes (freeform)
  String? tastingNotes;

  /// ABV percentage (optional, typically for alcoholic items)
  String? abv;

  /// Age or vintage (single field, meaning is user-defined)
  String? ageVintage;

  /// Price range tier (1-5, where 1 = $ and 5 = $$$$$)
  int? priceRange;

  /// Image URL or local path
  String? imageUrl;

  /// Where this entry came from
  @Enumerated(EnumType.name)
  CellarSource source = CellarSource.personal;

  /// Whether this is a favourite
  bool isFavorite = false;

  /// When the entry was created
  DateTime createdAt = DateTime.now();

  /// When the entry was last modified
  DateTime updatedAt = DateTime.now();

  /// Version for sync conflict resolution
  int version = 1;

  CellarEntry();

  /// Create a new cellar entry with required fields
  CellarEntry.create({
    required this.uuid,
    required this.name,
    this.producer,
    this.category,
    this.buy = false,
    this.tastingNotes,
    this.abv,
    this.ageVintage,
    this.priceRange,
    this.imageUrl,
    this.source = CellarSource.personal,
    this.isFavorite = false,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Create from JSON (for import)
  factory CellarEntry.fromJson(Map<String, dynamic> json) {
    final entry = CellarEntry()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..producer = json['producer'] as String?
      ..category = json['category'] as String?
      ..buy = json['buy'] as bool? ?? false
      ..tastingNotes = json['tastingNotes'] as String?
      ..abv = json['abv'] as String?
      ..ageVintage = json['ageVintage'] as String?
      ..priceRange = json['priceRange'] as int?
      ..imageUrl = json['imageUrl'] as String?
      ..source = CellarSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => CellarSource.personal,
      )
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..version = json['version'] as int? ?? 1;

    if (json['createdAt'] != null) {
      entry.createdAt = DateTime.parse(json['createdAt'] as String);
    }
    if (json['updatedAt'] != null) {
      entry.updatedAt = DateTime.parse(json['updatedAt'] as String);
    }

    return entry;
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
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
      'source': source.name,
      'isFavorite': isFavorite,
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
      'producer': producer,
      'category': category,
      'buy': buy,
      'tastingNotes': tastingNotes,
      'abv': abv,
      'ageVintage': ageVintage,
      'priceRange': priceRange,
      'imageUrl': imageUrl,
      'version': version,
    };
  }
}
