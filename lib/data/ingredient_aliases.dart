/// Canonical ingredient alias table.
///
/// Each key is the canonical (preferred) group name. The corresponding value
/// is a list of known synonyms. Keys and values should use already-normalized
/// forms (lowercase, singular, no preparation adjectives) so they align with
/// the output of [IngredientService.normalize].
///
/// Used in two places:
/// - Shopping list aggregation: synonyms are folded into the same list entry.
/// - Recipe FTS search: a user query matching any alias expands to OR all
///   terms in the group.
const Map<String, List<String>> ingredientAliases = {
  'green onion': ['scallion', 'spring onion'],
  'eggplant': ['aubergine'],
  'caster sugar': ['superfine sugar', 'castor sugar'],
  'courgette': ['zucchini'],
  'coriander': ['cilantro'],
};

/// Returns the canonical group key for [term], or [term] itself if no alias
/// group contains it.
///
/// Matching is case-insensitive. Call this after your existing normalization
/// pipeline so the incoming [term] is already in a clean, lowercase form.
///
/// ```dart
/// resolveIngredientAlias('scallion');      // → 'green onion'
/// resolveIngredientAlias('green onion');   // → 'green onion'
/// resolveIngredientAlias('chicken');       // → 'chicken'  (no alias group)
/// ```
String resolveIngredientAlias(String term) {
  final lower = term.toLowerCase();
  for (final entry in ingredientAliases.entries) {
    if (entry.key == lower) return entry.key;
    if (entry.value.any((alias) => alias.toLowerCase() == lower)) {
      return entry.key;
    }
  }
  return term;
}
