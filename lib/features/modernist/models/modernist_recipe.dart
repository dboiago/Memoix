import 'package:isar/isar.dart';

part 'modernist_recipe.g.dart';

/// Type of modernist recipe
enum ModernistType {
  concept,   // Unique flavor concepts - read like normal recipes
  technique, // Instructions for techniques like foams, spherification, etc.
}

extension ModernistTypeExtension on ModernistType {
  String get displayName {
    switch (this) {
      case ModernistType.concept:
        return 'Concept';
      case ModernistType.technique:
        return 'Technique';
    }
  }

  /// Parse from string
  static ModernistType fromString(String? value) {
    if (value == null || value.isEmpty) return ModernistType.concept;
    final lower = value.toLowerCase().trim();
    if (lower == 'technique') return ModernistType.technique;
    return ModernistType.concept;
  }
}

/// Source of the modernist recipe
enum ModernistSource {
  memoix,    // From official collection
  personal,  // User created
  imported,  // Shared from others
}

/// Common modernist techniques for autocomplete
class ModernistTechniques {
  ModernistTechniques._();

  static const List<String> all = [
    'Spherification',
    'Reverse Spherification',
    'Gelification',
    'Sous Vide',
    'Foams & Airs',
    'Emulsification',
    'Pressure Cooking',
    'Dehydration',
    'Smoking',
    'Infusion',
    'Cryogenic',
    'Centrifugation',
    'Fermentation',
    'Compression',
    'Transglutaminase',
    'Encapsulation',
    'Clarification',
    'Snow & Powders',
    'Gels',
    'Fluid Gels',
    'Meat Glue',
    'Hydrocolloids',
  ];

  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((t) => t.toLowerCase().contains(lower)).toList();
  }
}

/// Common modernist ingredients for autocomplete
class ModernistIngredients {
  ModernistIngredients._();

  static const List<String> all = [
    // Gelling agents
    'Agar Agar',
    'Gellan Gum',
    'Carrageenan (Iota)',
    'Carrageenan (Kappa)',
    'Sodium Alginate',
    'Methylcellulose',
    'Gelatin',
    
    // Spherification
    'Calcium Chloride',
    'Calcium Lactate',
    'Calcium Lactate Gluconate',
    
    // Emulsifiers & foaming
    'Soy Lecithin',
    'Xanthan Gum',
    'Gum Arabic',
    'Mono & Diglycerides',
    
    // Thickeners
    'Modified Starch',
    'Tapioca Maltodextrin',
    'N-Zorbit',
    'Ultra-Tex',
    
    // Enzymes
    'Transglutaminase (Meat Glue)',
    'Pectinex',
    'Amylase',
    
    // Sweeteners & misc
    'Glucose Syrup',
    'Isomalt',
    'Maltitol',
    'Citric Acid',
    'Malic Acid',
    'Ascorbic Acid',
    'Sodium Citrate',
    
    // Liquid nitrogen & CO2
    'Liquid Nitrogen',
    'Dry Ice',
  ];

  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((i) => i.toLowerCase().contains(lower)).toList();
  }
}

/// Common special equipment for modernist cooking
class ModernistEquipment {
  ModernistEquipment._();

  static const List<String> all = [
    'Immersion Blender',
    'Precision Scale (0.1g)',
    'Vacuum Sealer',
    'Sous Vide Circulator',
    'ISI Whip / Cream Whipper',
    'Pressure Cooker',
    'Dehydrator',
    'Centrifuge',
    'Smoking Gun',
    'Anti-Griddle',
    'Rotary Evaporator',
    'Pacojet',
    'Thermomix',
    'Induction Cooktop',
    'Infrared Thermometer',
    'pH Meter',
    'Refractometer',
    'Spherification Spoons (Perforated)',
    'Silicone Molds',
    'Squeeze Bottles',
    'Syringes',
    'Pipettes',
    'Chinois / Fine Mesh Strainer',
    'Cheesecloth',
    'Blowtorch',
    'Digital Probe Thermometer',
    'Magnetic Stirrer',
    'Homogenizer',
  ];

  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((e) => e.toLowerCase().contains(lower)).toList();
  }
}

/// Embedded ingredient for modernist recipes
@embedded
class ModernistIngredient {
  String name = '';
  String? amount;
  String? unit;
  String? notes;

  ModernistIngredient();

  ModernistIngredient.create({
    required this.name,
    this.amount,
    this.unit,
    this.notes,
  });

  /// Display string like "2g Sodium Alginate" or just "Agar Agar"
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

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'notes': notes,
  };

  factory ModernistIngredient.fromJson(Map<String, dynamic> json) {
    return ModernistIngredient()
      ..name = json['name'] as String? ?? ''
      ..amount = json['amount'] as String?
      ..unit = json['unit'] as String?
      ..notes = json['notes'] as String?;
  }
}

/// A modernist cooking recipe entity
@collection
class ModernistRecipe {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String name;

  /// Type of recipe: Concept or Technique
  @Enumerated(EnumType.name)
  ModernistType type = ModernistType.concept;

  /// Technique category (e.g., "Spherification", "Foams", etc.)
  /// Used for filtering and organization
  @Index()
  String? technique;

  /// Number of servings
  String? serves;

  /// Preparation/cooking time
  String? time;

  /// Difficulty level (optional)
  String? difficulty;

  /// Special equipment required (displayed ABOVE ingredients)
  List<String> equipment = [];

  /// Ingredients list
  List<ModernistIngredient> ingredients = [];

  /// Cooking directions
  List<String> directions = [];

  /// Tips and notes
  String? notes;

  /// Science notes (explanation of the technique/chemistry)
  String? scienceNotes;

  /// Source URL if imported
  String? sourceUrl;

  /// Image URL or local path
  String? imageUrl;

  /// Multiple image support
  List<String> imageUrls = [];

  /// Whether this is a favorite
  bool isFavorite = false;

  /// How many times this has been made
  int cookCount = 0;

  /// Source of the recipe
  @Enumerated(EnumType.name)
  ModernistSource source = ModernistSource.personal;

  /// Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  ModernistRecipe();

  /// Factory constructor
  static ModernistRecipe create({
    required String uuid,
    required String name,
    ModernistType type = ModernistType.concept,
    String? technique,
    String? serves,
    String? time,
    String? difficulty,
    List<String>? equipment,
    List<ModernistIngredient>? ingredients,
    List<String>? directions,
    String? notes,
    String? scienceNotes,
    String? sourceUrl,
    String? imageUrl,
    List<String>? imageUrls,
    bool isFavorite = false,
    int cookCount = 0,
    ModernistSource source = ModernistSource.personal,
  }) {
    return ModernistRecipe()
      ..uuid = uuid
      ..name = name
      ..type = type
      ..technique = technique
      ..serves = serves
      ..time = time
      ..difficulty = difficulty
      ..equipment = equipment ?? []
      ..ingredients = ingredients ?? []
      ..directions = directions ?? []
      ..notes = notes
      ..scienceNotes = scienceNotes
      ..sourceUrl = sourceUrl
      ..imageUrl = imageUrl
      ..imageUrls = imageUrls ?? []
      ..isFavorite = isFavorite
      ..cookCount = cookCount
      ..source = source
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  /// Get all images (handles both imageUrls and legacy imageUrl)
  List<String> getAllImages() {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return [];
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'type': type.name,
      'technique': technique,
      'serves': serves,
      'time': time,
      'difficulty': difficulty,
      'equipment': equipment,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'directions': directions,
      'notes': notes,
      'scienceNotes': scienceNotes,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'isFavorite': isFavorite,
      'cookCount': cookCount,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ModernistRecipe.fromJson(Map<String, dynamic> json) {
    return ModernistRecipe()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..type = ModernistType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ModernistType.concept,
      )
      ..technique = json['technique'] as String?
      ..serves = json['serves'] as String?
      ..time = json['time'] as String?
      ..difficulty = json['difficulty'] as String?
      ..equipment = (json['equipment'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..ingredients = (json['ingredients'] as List<dynamic>?)
          ?.map((e) => ModernistIngredient.fromJson(e as Map<String, dynamic>))
          .toList() ?? []
      ..directions = (json['directions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..notes = json['notes'] as String?
      ..scienceNotes = json['scienceNotes'] as String?
      ..sourceUrl = json['sourceUrl'] as String?
      ..imageUrl = json['imageUrl'] as String?
      ..imageUrls = (json['imageUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..cookCount = json['cookCount'] as int? ?? 0
      ..source = ModernistSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ModernistSource.personal,
      );
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'type': type.name,
      'technique': technique,
      'serves': serves,
      'time': time,
      'difficulty': difficulty,
      'equipment': equipment,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'directions': directions,
      'notes': notes,
      'scienceNotes': scienceNotes,
      'sourceUrl': sourceUrl,
    };
  }
}
