/// Root-scoped cache for AI ingredient reference results.
///
/// Survives navigation — scoped to the app root, NOT to a detail screen.
/// Session lifetime only — no Isar or SharedPreferences persistence.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient_reference.dart';
import '../services/ingredient_reference_service.dart';

/// Normalise the cache key: trim, lowercase, collapse internal whitespace.
String _cacheKey(String ingredientName) {
  return ingredientName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// In-memory cache holding parsed [IngredientReferenceResult] objects.
///
/// Exposed as a [StateNotifier] so the provider is root-scoped by default
/// (Riverpod keeps `StateNotifierProvider` instances alive at the root).
class IngredientReferenceCacheNotifier
    extends StateNotifier<Map<String, IngredientReferenceResult>> {
  IngredientReferenceCacheNotifier() : super({});

  /// Returns a cached result for [ingredientName], or `null` on miss.
  IngredientReferenceResult? lookup(String ingredientName) {
    return state[_cacheKey(ingredientName)];
  }

  /// Store a successfully-fetched result.
  void store(String ingredientName, IngredientReferenceResult result) {
    state = {...state, _cacheKey(ingredientName): result};
  }
}

/// Root-scoped provider for the ingredient reference cache.
final ingredientReferenceCacheProvider = StateNotifierProvider<
    IngredientReferenceCacheNotifier,
    Map<String, IngredientReferenceResult>>(
  (ref) => IngredientReferenceCacheNotifier(),
);
