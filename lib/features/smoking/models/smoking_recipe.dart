import 'package:isar/isar.dart';

part 'smoking_recipe.g.dart';

/// Common wood suggestions for autocomplete
/// Users can enter any wood type they want
class WoodSuggestions {
  WoodSuggestions._();

  static const List<String> common = [
    'Hickory',
    'Mesquite',
    'Apple',
    'Cherry',
    'Pecan',
    'Oak',
    'Maple',
    'Alder',
    'Peach',
    'Pear',
    'Walnut',
    'Mulberry',
    'Olive',
    'Grapevine',
    'Beech',
    'Ash',
    'Birch',
    'Chestnut',
    'Citrus',
    'Fig',
    'Lemon',
    'Nectarine',
    'Plum',
    'Apricot',
  ];

  /// Get suggestions matching a query
  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return common;
    final lower = query.toLowerCase();
    return common.where((w) => w.toLowerCase().contains(lower)).toList();
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

  /// Type of wood used (free-form text)
  @Index()
  late String wood;

  /// Seasonings/rub ingredients
  List<SmokingSeasoning> seasonings = [];

  /// Cooking directions
  List<String> directions = [];

  /// Optional notes
  String? notes;

  /// Optional image
  String? imageUrl;

  /// Whether this is a favorite
  bool isFavorite = false;

  /// How many times this has been cooked
  int cookCount = 0;

  /// Source of the recipe
  @Enumerated(EnumType.name)
  SmokingSource source = SmokingSource.personal;

  /// Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  SmokingRecipe();

  /// Factory constructor for creating with required fields
  static SmokingRecipe create({
    required String uuid,
    required String name,
    required String temperature,
    required String time,
    required String wood,
    List<SmokingSeasoning>? seasonings,
    List<String>? directions,
    String? notes,
    String? imageUrl,
    bool isFavorite = false,
    int cookCount = 0,
    SmokingSource source = SmokingSource.personal,
  }) {
    return SmokingRecipe()
      ..uuid = uuid
      ..name = name
      ..temperature = temperature
      ..time = time
      ..wood = wood
      ..seasonings = seasonings ?? []
      ..directions = directions ?? []
      ..notes = notes
      ..imageUrl = imageUrl
      ..isFavorite = isFavorite
      ..cookCount = cookCount
      ..source = source
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'temperature': temperature,
      'time': time,
      'wood': wood,
      'seasonings': seasonings.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'unit': s.unit,
      }).toList(),
      'directions': directions,
      'notes': notes,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'cookCount': cookCount,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'temperature': temperature,
      'time': time,
      'wood': wood,
      'seasonings': seasonings.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'unit': s.unit,
      }).toList(),
      'directions': directions,
      'notes': notes,
    };
  }
}
