import 'package:isar/isar.dart';

part 'smoking_recipe.g.dart';

/// Common wood types for smoking
enum WoodType {
  hickory,
  mesquite,
  applewood,
  cherrywood,
  pecanwood,
  oakwood,
  maplewood,
  alderwood,
  peachwood,
  pearwood,
  walnut,
  other,
}

extension WoodTypeExtension on WoodType {
  String get displayName {
    switch (this) {
      case WoodType.hickory:
        return 'Hickory';
      case WoodType.mesquite:
        return 'Mesquite';
      case WoodType.applewood:
        return 'Apple';
      case WoodType.cherrywood:
        return 'Cherry';
      case WoodType.pecanwood:
        return 'Pecan';
      case WoodType.oakwood:
        return 'Oak';
      case WoodType.maplewood:
        return 'Maple';
      case WoodType.alderwood:
        return 'Alder';
      case WoodType.peachwood:
        return 'Peach';
      case WoodType.pearwood:
        return 'Pear';
      case WoodType.walnut:
        return 'Walnut';
      case WoodType.other:
        return 'Other';
    }
  }

  static WoodType fromString(String value) {
    final lower = value.toLowerCase().trim();
    for (final wood in WoodType.values) {
      if (wood.name == lower || wood.displayName.toLowerCase() == lower) {
        return wood;
      }
    }
    return WoodType.other;
  }
}

/// Source of the smoking recipe
enum SmokingSource {
  memoix,    // From official collection
  personal,  // User created
  imported,  // Shared from others
}

/// Seasoning/rub ingredient for smoking
@embedded
class SmokingSeasoning {
  String name = '';
  String? amount;
  String? unit;
  
  SmokingSeasoning();
  
  SmokingSeasoning.create({
    required this.name,
    this.amount,
    this.unit,
  });

  /// Display string like "2 Tbsp Sugar" or just "Salt"
  String get displayText {
    final parts = <String>[];
    if (amount != null && amount!.isNotEmpty) {
      parts.add(amount!);
    }
    if (unit != null && unit!.isNotEmpty) {
      parts.add(unit!);
    }
    parts.add(name);
    return parts.join(' ');
  }
}

/// A smoking recipe entity
@collection
class SmokingRecipe {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String name;

  /// Temperature for smoking (e.g., "275°F", "135°C")
  late String temperature;

  /// Smoking duration (e.g., "3 hrs", "6-8 hours")
  late String time;

  /// Type of wood used
  @Enumerated(EnumType.name)
  WoodType wood = WoodType.hickory;

  /// Custom wood name if wood == other
  String? customWood;

  /// Seasonings/rub ingredients
  List<SmokingSeasoning> seasonings = [];

  /// Cooking directions
  List<String> directions = [];

  /// Optional notes
  String? notes;

  /// Optional image
  String? imageUrl;

  /// Source of the recipe
  @Enumerated(EnumType.name)
  SmokingSource source = SmokingSource.personal;

  /// Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  SmokingRecipe();

  /// Get display name for wood (handles custom)
  String get woodDisplayName {
    if (wood == WoodType.other && customWood != null && customWood!.isNotEmpty) {
      return customWood!;
    }
    return wood.displayName;
  }

  /// Factory constructor for creating with required fields
  static SmokingRecipe create({
    required String uuid,
    required String name,
    required String temperature,
    required String time,
    WoodType wood = WoodType.hickory,
    String? customWood,
    List<SmokingSeasoning>? seasonings,
    List<String>? directions,
    String? notes,
    String? imageUrl,
    SmokingSource source = SmokingSource.personal,
  }) {
    return SmokingRecipe()
      ..uuid = uuid
      ..name = name
      ..temperature = temperature
      ..time = time
      ..wood = wood
      ..customWood = customWood
      ..seasonings = seasonings ?? []
      ..directions = directions ?? []
      ..notes = notes
      ..imageUrl = imageUrl
      ..source = source
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }
}
