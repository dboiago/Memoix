import 'package:isar/isar.dart';

part 'cheese_entry.g.dart';

/// Source of the cheese entry
enum CheeseSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own entries
  imported, // Shared with the user
}

@collection
class CheeseEntry {
  Id id = Isar.autoIncrement;

  /// Unique identifier for sharing and syncing
  @Index(unique: true, replace: true)
  late String uuid;

  /// Cheese name
  @Index(type: IndexType.value)
  late String name;

  /// Country of origin
  String? country;

  /// Type of milk (cow, goat, sheep, etc.)
  String? milk;

  /// Texture description (soft, semi-soft, hard, etc.)
  String? texture;

  /// Cheese type/style (blue, brie, cheddar, etc.)
  String? type;

  /// Would buy again
  bool buy = false;

  /// Flavour notes (freeform)
  String? flavour;

  /// Price range tier (1-5, where 1 = $ and 5 = $$$$$)
  int? priceRange;

  /// Image URL or local path
  String? imageUrl;

  /// Where this entry came from
  @Enumerated(EnumType.name)
  CheeseSource source = CheeseSource.personal;

  /// Whether this is a favourite
  bool isFavorite = false;

  /// When the entry was created
  DateTime createdAt = DateTime.now();

  /// When the entry was last modified
  DateTime updatedAt = DateTime.now();

  /// Version for sync conflict resolution
  int version = 1;

  CheeseEntry();

  /// Create a new cheese entry with required fields
  CheeseEntry.create({
    required this.uuid,
    required this.name,
    this.country,
    this.milk,
    this.texture,
    this.type,
    this.buy = false,
    this.flavour,
    this.priceRange, // 1-5 tier rating
    this.imageUrl,
    this.source = CheeseSource.personal,
    this.isFavorite = false,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Create from JSON (for import)
  factory CheeseEntry.fromJson(Map<String, dynamic> json) {
    final entry = CheeseEntry()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..country = json['country'] as String?
      ..milk = json['milk'] as String?
      ..texture = json['texture'] as String?
      ..type = json['type'] as String?
      ..buy = json['buy'] as bool? ?? false
      ..flavour = json['flavour'] as String?
      ..priceRange = json['priceRange'] as int?
      ..imageUrl = json['imageUrl'] as String?
      ..source = CheeseSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => CheeseSource.personal,
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
      'country': country,
      'milk': milk,
      'texture': texture,
      'type': type,
      'buy': buy,
      'flavour': flavour,
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
      'country': country,
      'milk': milk,
      'texture': texture,
      'type': type,
      'buy': buy,
      'flavour': flavour,
      'priceRange': priceRange,
      'imageUrl': imageUrl,
      'version': version,
    };
  }
}
