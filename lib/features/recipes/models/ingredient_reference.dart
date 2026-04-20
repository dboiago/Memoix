/// AI-generated reference information for a single ingredient.
///
/// Parsed from the JSON returned by the AI culinary reference assistant.
/// Cached in a root-scoped Riverpod provider for the session lifetime.
class IngredientReference {
  final String description;
  final List<String> aliases;
  final String flavor;
  final List<IngredientSubstitution> substitutions;

  const IngredientReference({
    required this.description,
    required this.aliases,
    required this.flavor,
    required this.substitutions,
  });

  /// Parse the AI JSON response into a typed result.
  ///
  /// Follows the same try/parse pattern used by [RecipeImportResult.fromAi].
  /// Throws [FormatException] if the shape is unexpected — callers wrap
  /// this in try/catch and treat any failure as a fetch error.
  factory IngredientReference.fromJson(Map<String, dynamic> json) {
    final description = (json['description'] as String?) ?? '';
    final aliases = (json['aliases'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const [];
    final flavor = (json['flavor'] as String?) ?? '';
    final subs = (json['substitutions'] as List<dynamic>?)
            ?.map((e) => IngredientSubstitution.fromJson(
                e as Map<String, dynamic>,),)
            .toList() ??
        const [];

    return IngredientReference(
      description: description,
      aliases: aliases,
      flavor: flavor,
      substitutions: subs,
    );
  }
}

/// A single substitution suggestion inside [IngredientReference].
class IngredientSubstitution {
  final String name;

  /// Units of substitute per 1 unit of original.
  /// `null` when the AI omitted the field (uncertain).
  final double? ratio;

  final String note;

  const IngredientSubstitution({
    required this.name,
    this.ratio,
    required this.note,
  });

  factory IngredientSubstitution.fromJson(Map<String, dynamic> json) {
    return IngredientSubstitution(
      name: (json['name'] as String?) ?? '',
      ratio: (json['ratio'] as num?)?.toDouble(),
      note: (json['note'] as String?) ?? '',
    );
  }
}
