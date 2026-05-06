import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/cellar/models/cellar_entry.dart';
import '../../features/cheese/models/cheese_entry.dart';
import '../../features/modernist/models/modernist_recipe.dart';
import '../database/app_database.dart' hide Recipe;
import '../../features/pizzas/models/pizza.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/sandwiches/models/sandwich.dart';
import '../../features/smoking/models/smoking_recipe.dart';

/// Computes stable and content hashes for RAG telemetry payloads.
///
/// All hashes use SHA-256 over a deterministic UTF-8 string. The canonical
/// separator between fields is the zero-width no-break space (U+FEFF) so that
/// adjacent field values can never be confused for each other.
abstract class PayloadHasher {
  PayloadHasher._();

  static const _sep = '\uFEFF';

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ───────────────────────────────────────────────────────────────
  // Pairing hash — lightweight name+course identifier
  // ───────────────────────────────────────────────────────────────

  /// SHA-256 of `name + course` only.
  ///
  /// Used in the `pairedRecipes` payload array to identify a peer recipe
  /// without exposing its UUID.
  static String pairingHash(String name, String course) {
    final input =
        '${name.trim().toLowerCase()}$_sep${course.trim().toLowerCase()}';
    return _sha256(input);
  }

  // ───────────────────────────────────────────────────────────────
  // Lineage hash — stable across edits to identity fields
  // ───────────────────────────────────────────────────────────────

  /// SHA-256 of normalised `name + course + sorted ingredient names`.
  ///
  /// Ingredient names are lower-cased and sorted before hashing so that
  /// reordering ingredients does not change the lineage.
  static String recipeLineageHash(Recipe recipe) {
    final sortedNames = recipe.ingredients
        .map((i) => i.name.trim().toLowerCase())
        .toList()
      ..sort();
    final input =
        '${recipe.name.trim().toLowerCase()}$_sep${recipe.course.trim().toLowerCase()}$_sep${sortedNames.join(_sep)}';
    return _sha256(input);
  }

  /// Lineage hash for a [ModernistRecipe].
  static String modernistLineageHash(ModernistRecipe recipe) {
    final sortedNames = recipe.ingredients
        .map((i) => i.name.trim().toLowerCase())
        .toList()
      ..sort();
    final input =
        '${recipe.name.trim().toLowerCase()}$_sep${recipe.course.trim().toLowerCase()}$_sep${sortedNames.join(_sep)}';
    return _sha256(input);
  }

  /// Lineage hash for a [SmokingRecipe].
  /// Uses ingredient names from `ingredientsJson` (seasoning names excluded —
  /// seasonings are modifiable per-cook).
  static String smokingLineageHash(SmokingRecipe recipe) {
    final ings = (jsonDecode(recipe.ingredientsJson) as List)
        .map((m) => (m as Map<String, dynamic>)['name']?.toString().trim().toLowerCase() ?? '')
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();
    final input =
        '${recipe.name.trim().toLowerCase()}$_sep${recipe.course.trim().toLowerCase()}$_sep${(recipe.item ?? '').trim().toLowerCase()}$_sep${ings.join(_sep)}';
    return _sha256(input);
  }

  /// Lineage hash for a [Pizza].
  static String pizzaLineageHash(Pizza pizza) {
    final cheeses = (jsonDecode(pizza.cheeses) as List)
        .cast<String>()
        .map((s) => s.trim().toLowerCase())
        .toList()
      ..sort();
    final proteins = (jsonDecode(pizza.proteins) as List)
        .cast<String>()
        .map((s) => s.trim().toLowerCase())
        .toList()
      ..sort();
    final input =
        '${pizza.name.trim().toLowerCase()}$_sep${pizza.base.trim().toLowerCase()}$_sep${cheeses.join(_sep)}$_sep${proteins.join(_sep)}';
    return _sha256(input);
  }

  /// Lineage hash for a [Sandwich].
  static String sandwichLineageHash(Sandwich sandwich) {
    final proteins = (jsonDecode(sandwich.proteins) as List)
        .cast<String>()
        .map((s) => s.trim().toLowerCase())
        .toList()
      ..sort();
    final input =
        '${sandwich.name.trim().toLowerCase()}$_sep${sandwich.bread.trim().toLowerCase()}$_sep${proteins.join(_sep)}';
    return _sha256(input);
  }

  // ───────────────────────────────────────────────────────────────
  // Content hash — recomputed on every transmission
  // ───────────────────────────────────────────────────────────────

  /// SHA-256 of the full current recipe content.
  ///
  /// Covers all fields that affect culinary meaning. Personal-only fields
  /// (isFavourite, cookCount, rating, imageUrls) are excluded.
  static String recipeContentHash(Recipe recipe) {
    final ingParts = recipe.ingredients
        .map((i) =>
            '${i.name}:${i.amount ?? ''}:${i.unit ?? ''}:${i.preparation ?? ''}:${i.isOptional}:${i.section ?? ''}')
        .join(_sep);
    final input = [
      recipe.name,
      recipe.course,
      recipe.cuisine ?? '',
      recipe.subcategory ?? '',
      recipe.serves ?? '',
      recipe.time ?? '',
      recipe.comments ?? '',
      recipe.directions.join(_sep),
      ingParts,
      recipe.tags.join(_sep),
      recipe.source.name,
      recipe.recipeType,
      recipe.modernistType ?? '',
      recipe.smokingType ?? '',
      recipe.glass ?? '',
      recipe.garnish.join(_sep),
      recipe.pickleMethod ?? '',
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current modernist recipe content.
  static String modernistContentHash(ModernistRecipe recipe) {
    final ingParts = recipe.ingredients
        .map((i) =>
            '${i.name}:${i.amount ?? ''}:${i.unit ?? ''}:${i.notes ?? ''}:${i.section ?? ''}')
        .join(_sep);
    final input = [
      recipe.name,
      recipe.course,
      recipe.type.name,
      recipe.technique ?? '',
      recipe.serves ?? '',
      recipe.time ?? '',
      recipe.difficulty ?? '',
      recipe.equipment.join(_sep),
      ingParts,
      recipe.directions.join(_sep),
      recipe.notes ?? '',
      recipe.scienceNotes ?? '',
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current smoking recipe content.
  static String smokingContentHash(SmokingRecipe recipe) {
    final input = [
      recipe.name,
      recipe.course,
      recipe.type,
      recipe.item ?? '',
      recipe.category ?? '',
      recipe.temperature,
      recipe.time,
      recipe.wood,
      recipe.seasoningsJson,
      recipe.ingredientsJson,
      recipe.serves ?? '',
      recipe.directions,
      recipe.notes ?? '',
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current pizza content.
  static String pizzaContentHash(Pizza pizza) {
    final input = [
      pizza.name,
      pizza.base,
      pizza.cheeses,
      pizza.proteins,
      pizza.vegetables,
      pizza.notes ?? '',
      pizza.tags,
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current sandwich content.
  static String sandwichContentHash(Sandwich sandwich) {
    final input = [
      sandwich.name,
      sandwich.bread,
      sandwich.proteins,
      sandwich.vegetables,
      sandwich.cheeses,
      sandwich.condiments,
      sandwich.notes ?? '',
      sandwich.tags,
    ].join(_sep);
    return _sha256(input);
  }

  // ───────────────────────────────────────────────────────────────
  // Cellar
  // ───────────────────────────────────────────────────────────────

  /// SHA-256 of `name + producer + category`.
  ///
  /// These three fields together identify a specific beverage product in the
  /// cellar log. Producer and category default to empty string when null.
  static String cellarLineageHash(CellarEntry entry) {
    final input = [
      entry.name.trim().toLowerCase(),
      (entry.producer ?? '').trim().toLowerCase(),
      (entry.category ?? '').trim().toLowerCase(),
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current cellar entry content.
  ///
  /// Covers all descriptive fields. Personal-only fields (isFavorite, buy,
  /// imageUrl) are excluded.
  static String cellarContentHash(CellarEntry entry) {
    final input = [
      entry.name,
      entry.producer ?? '',
      entry.category ?? '',
      entry.tastingNotes ?? '',
      entry.abv ?? '',
      entry.ageVintage ?? '',
      entry.priceRange?.toString() ?? '',
      entry.source,
    ].join(_sep);
    return _sha256(input);
  }

  // ───────────────────────────────────────────────────────────────
  // Cheese
  // ───────────────────────────────────────────────────────────────

  /// SHA-256 of `name + country + milk + type`.
  ///
  /// These four fields together identify a specific cheese in the catalogue.
  /// Fields default to empty string when null.
  static String cheeseLineageHash(CheeseEntry entry) {
    final input = [
      entry.name.trim().toLowerCase(),
      (entry.country ?? '').trim().toLowerCase(),
      (entry.milk ?? '').trim().toLowerCase(),
      (entry.type ?? '').trim().toLowerCase(),
    ].join(_sep);
    return _sha256(input);
  }

  /// SHA-256 of the full current cheese entry content.
  ///
  /// Covers all descriptive fields. Personal-only fields (isFavourite, buy,
  /// imageUrl) are excluded.
  static String cheeseContentHash(CheeseEntry entry) {
    final input = [
      entry.name,
      entry.country ?? '',
      entry.milk ?? '',
      entry.texture ?? '',
      entry.type ?? '',
      entry.flavour ?? '',
      entry.priceRange?.toString() ?? '',
      entry.source,
    ].join(_sep);
    return _sha256(input);
  }
}
