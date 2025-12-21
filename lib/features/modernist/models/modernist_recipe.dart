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
  
  /// Section/group header (e.g., "For the Gel", "For the Foam")
  String? section;

  ModernistIngredient();

  ModernistIngredient.create({
    required this.name,
    this.amount,
    this.unit,
    this.notes,
    this.section,
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
    'section': section,
  };

  factory ModernistIngredient.fromJson(Map<String, dynamic> json) {
    return ModernistIngredient()
      ..name = json['name'] as String? ?? ''
      ..amount = json['amount'] as String?
      ..unit = json['unit'] as String?
      ..notes = json['notes'] as String?
      ..section = json['section'] as String?;
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

  /// Course (e.g., "Mains", "Desserts", "Sauces")
  /// Defaults to "modernist" but can be changed
  @Index()
  String course = 'modernist';

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

  /// Main header image (shown in app bar)
  String? headerImage;

  /// Gallery images for steps (shown at bottom)
  List<String> stepImages = [];

  /// Map of step index to image index in stepImages
  /// Stored as "stepIndex:imageIndex" strings for Isar compatibility
  List<String> stepImageMap = [];

  /// Legacy: Image URL or local path (deprecated, use headerImage)
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

  /// Paired recipe IDs (links to related Recipe items)
  List<String> pairedRecipeIds = [];

  /// Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  ModernistRecipe();

  /// Factory constructor
  static ModernistRecipe create({
    required String uuid,
    required String name,
    String course = 'modernist',
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
    String? headerImage,
    List<String>? stepImages,
    List<String>? stepImageMap,
    String? imageUrl,
    List<String>? imageUrls,
    bool isFavorite = false,
    int cookCount = 0,
    ModernistSource source = ModernistSource.personal,
    List<String>? pairedRecipeIds,
  }) {
    return ModernistRecipe()
      ..uuid = uuid
      ..name = name
      ..course = course
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
      ..headerImage = headerImage
      ..stepImages = stepImages ?? []
      ..stepImageMap = stepImageMap ?? []
      ..imageUrl = imageUrl
      ..imageUrls = imageUrls ?? []
      ..isFavorite = isFavorite
      ..cookCount = cookCount
      ..source = source
      ..pairedRecipeIds = pairedRecipeIds ?? []
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  /// Get all images (handles new structure and legacy fields)
  List<String> getAllImages() {
    final images = <String>[];
    if (headerImage != null && headerImage!.isNotEmpty) {
      images.add(headerImage!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Legacy fallback
      images.add(imageUrl!);
    }
    if (stepImages.isNotEmpty) {
      images.addAll(stepImages);
    } else if (imageUrls.isNotEmpty) {
      // Legacy fallback
      images.addAll(imageUrls.where((u) => u != headerImage && u != imageUrl));
    }
    return images;
  }

  /// Get first image if available (headerImage or legacy imageUrl)
  String? getFirstImage() {
    if (headerImage != null && headerImage!.isNotEmpty) return headerImage;
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    return null;
  }

  /// Get image index for a specific step (0-based)
  /// Returns null if no image is associated with this step
  int? getStepImageIndex(int stepIndex) {
    for (final mapping in stepImageMap) {
      final parts = mapping.split(':');
      if (parts.length == 2) {
        final sIdx = int.tryParse(parts[0]);
        final iIdx = int.tryParse(parts[1]);
        if (sIdx == stepIndex && iIdx != null) {
          return iIdx;
        }
      }
    }
    return null;
  }

  /// Get the image path for a specific step
  String? getStepImage(int stepIndex) {
    final imageIndex = getStepImageIndex(stepIndex);
    if (imageIndex != null && imageIndex < stepImages.length) {
      return stepImages[imageIndex];
    }
    return null;
  }

  /// Set image association for a step
  void setStepImage(int stepIndex, int imageIndex) {
    // Remove existing mapping for this step
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
    // Add new mapping
    stepImageMap.add('$stepIndex:$imageIndex');
  }

  /// Remove image association for a step
  void removeStepImage(int stepIndex) {
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'course': course,
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
      'headerImage': headerImage,
      'stepImages': stepImages,
      'stepImageMap': stepImageMap,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'isFavorite': isFavorite,
      'cookCount': cookCount,
      'source': source.name,
      'pairedRecipeIds': pairedRecipeIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ModernistRecipe.fromJson(Map<String, dynamic> json) {
    return ModernistRecipe()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..course = json['course'] as String? ?? 'modernist'
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
      ..headerImage = json['headerImage'] as String?
      ..stepImages = (json['stepImages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..stepImageMap = (json['stepImageMap'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..imageUrl = json['imageUrl'] as String?
      ..imageUrls = (json['imageUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..cookCount = json['cookCount'] as int? ?? 0
      ..source = ModernistSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ModernistSource.personal,
      )
      ..pairedRecipeIds = (json['pairedRecipeIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [];
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'course': course,
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
