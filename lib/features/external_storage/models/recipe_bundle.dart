import 'dart:convert';

import '../../cellar/models/cellar_entry.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../pizzas/models/pizza.dart';
import '../../recipes/models/recipe.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../smoking/models/smoking_recipe.dart';
import 'storage_meta.dart';

/// Container for all recipe data to be pushed/pulled from external storage
/// 
/// Represents the `memoix_recipes.json` file structure.
/// Contains recipes from all domains (Recipes, Pizzas, Sandwiches, etc.)
class RecipeBundle {
  /// Standard recipes (Mains, Desserts, Drinks, Soups, etc.)
  final List<Recipe> recipes;

  /// Pizza recipes
  final List<Pizza> pizzas;

  /// Sandwich recipes
  final List<Sandwich> sandwiches;

  /// Cheese journal entries
  final List<CheeseEntry> cheeses;

  /// Cellar entries (wine, spirits, etc.)
  final List<CellarEntry> cellar;

  /// Smoking/BBQ recipes
  final List<SmokingRecipe> smoking;

  /// Modernist/molecular gastronomy recipes
  final List<ModernistRecipe> modernist;

  /// Bundle metadata (version, timestamp, etc.)
  final BundleMetadata metadata;

  const RecipeBundle({
    this.recipes = const [],
    this.pizzas = const [],
    this.sandwiches = const [],
    this.cheeses = const [],
    this.cellar = const [],
    this.smoking = const [],
    this.modernist = const [],
    required this.metadata,
  });

  /// Create an empty bundle
  factory RecipeBundle.empty() {
    return RecipeBundle(
      metadata: BundleMetadata.create(),
    );
  }

  /// Total number of items across all domains
  int get totalCount =>
      recipes.length +
      pizzas.length +
      sandwiches.length +
      cheeses.length +
      cellar.length +
      smoking.length +
      modernist.length;

  /// Get domain counts for meta file
  DomainCounts get domainCounts => DomainCounts(
        recipes: recipes.length,
        pizzas: pizzas.length,
        sandwiches: sandwiches.length,
        cheeses: cheeses.length,
        cellar: cellar.length,
        smoking: smoking.length,
        modernist: modernist.length,
      );

  /// Create from JSON string
  factory RecipeBundle.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return RecipeBundle.fromJson(json);
  }

  /// Create from JSON map
  factory RecipeBundle.fromJson(Map<String, dynamic> json) {
    return RecipeBundle(
      recipes: (json['recipes'] as List<dynamic>?)
              ?.map((e) => Recipe.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pizzas: (json['pizzas'] as List<dynamic>?)
              ?.map((e) => Pizza.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sandwiches: (json['sandwiches'] as List<dynamic>?)
              ?.map((e) => Sandwich.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cheeses: (json['cheeses'] as List<dynamic>?)
              ?.map((e) => CheeseEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cellar: (json['cellar'] as List<dynamic>?)
              ?.map((e) => CellarEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      smoking: (json['smoking'] as List<dynamic>?)
              ?.map((e) => SmokingRecipe.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      modernist: (json['modernist'] as List<dynamic>?)
              ?.map((e) => ModernistRecipe.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['_metadata'] != null
          ? BundleMetadata.fromJson(json['_metadata'] as Map<String, dynamic>)
          : BundleMetadata.create(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      '_metadata': metadata.toJson(),
      'recipes': recipes.map((e) => e.toJson()).toList(),
      'pizzas': pizzas.map((e) => e.toJson()).toList(),
      'sandwiches': sandwiches.map((e) => e.toJson()).toList(),
      'cheeses': cheeses.map((e) => e.toJson()).toList(),
      'cellar': cellar.map((e) => e.toJson()).toList(),
      'smoking': smoking.map((e) => e.toJson()).toList(),
      'modernist': modernist.map((e) => e.toJson()).toList(),
    };
  }

  /// Convert to JSON string
  String toJsonString({bool pretty = false}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  /// Create a copy with updated fields
  RecipeBundle copyWith({
    List<Recipe>? recipes,
    List<Pizza>? pizzas,
    List<Sandwich>? sandwiches,
    List<CheeseEntry>? cheeses,
    List<CellarEntry>? cellar,
    List<SmokingRecipe>? smoking,
    List<ModernistRecipe>? modernist,
    BundleMetadata? metadata,
  }) {
    return RecipeBundle(
      recipes: recipes ?? this.recipes,
      pizzas: pizzas ?? this.pizzas,
      sandwiches: sandwiches ?? this.sandwiches,
      cheeses: cheeses ?? this.cheeses,
      cellar: cellar ?? this.cellar,
      smoking: smoking ?? this.smoking,
      modernist: modernist ?? this.modernist,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'RecipeBundle(total: $totalCount, recipes: ${recipes.length}, '
        'pizzas: ${pizzas.length}, sandwiches: ${sandwiches.length}, '
        'cheeses: ${cheeses.length}, cellar: ${cellar.length}, '
        'smoking: ${smoking.length}, modernist: ${modernist.length})';
  }
}

/// Embedded metadata within the bundle file
/// 
/// This is included in the JSON file itself (as `_metadata`) for
/// quick reference without needing a separate meta file.
class BundleMetadata {
  /// Bundle format version
  final int version;

  /// Schema version of the data format
  final int schemaVersion;

  /// When this bundle was created
  final DateTime createdAt;

  /// Device that created this bundle
  final String createdBy;

  /// App version that created this bundle
  final String? appVersion;

  const BundleMetadata({
    required this.version,
    required this.schemaVersion,
    required this.createdAt,
    required this.createdBy,
    this.appVersion,
  });

  /// Create with current timestamp
  factory BundleMetadata.create({
    String? deviceName,
    String? appVersion,
  }) {
    return BundleMetadata(
      version: 1,
      schemaVersion: 3,
      createdAt: DateTime.now().toUtc(),
      createdBy: deviceName ?? 'Unknown Device',
      appVersion: appVersion,
    );
  }

  /// Create from JSON map
  factory BundleMetadata.fromJson(Map<String, dynamic> json) {
    return BundleMetadata(
      version: json['version'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now().toUtc(),
      createdBy: json['createdBy'] as String? ?? 'Unknown',
      appVersion: json['appVersion'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdBy': createdBy,
      if (appVersion != null) 'appVersion': appVersion,
    };
  }

  @override
  String toString() {
    return 'BundleMetadata(version: $version, schemaVersion: $schemaVersion, '
        'createdAt: $createdAt, createdBy: $createdBy)';
  }
}
