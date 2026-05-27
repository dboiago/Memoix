/// A single result returned by the RAG retrieval pipeline.
///
/// Mirrors the data shape of the omnibar's internal candidate model so that
/// results can be displayed using the same presentation logic, while adding
/// [similarityScore] for ranking by vector distance.
///
/// All fields map directly to Supabase/Postgres column names (snake_case) via
/// [RagQueryResult.fromJson].
class RagQueryResult {
  /// Recipe or entry name.
  final String name;

  /// Course slug identifying the domain (e.g. `'mains'`, `'desserts'`, `'cellar'`).
  final String courseLabel;

  /// Whether the user has marked this recipe as a favourite.
  final bool isFavourite;

  /// Number of times the recipe has been cooked.
  final int cookCount;

  /// Date the recipe was last cooked. Null when never cooked.
  final DateTime? lastCookedAt;

  /// Whether the recipe originates from the bundled Memoix library.
  final bool isMemoix;

  /// Human-readable total time string (e.g. `'45m'`, `'1h 20m'`). Null when
  /// not specified.
  final String? time;

  /// Whether the result is a smoking pit note rather than a cook recipe.
  final bool isPitNote;

  /// Cuisine name. Null when not specified.
  final String? cuisine;

  /// Ingredient names used for ingredient-based filtering.
  final List<String> ingredientNames;

  /// Cosine similarity score in the range [0, 1] returned by the vector store.
  /// Higher values indicate stronger semantic relevance to the query.
  final double similarityScore;

  /// Geographic region (e.g. `'Eastern Europe'`). Null when not specified.
  final String? region;

  /// Technique or method label (e.g. `'slow-cooked'`). Null when not specified.
  final String? technique;

  /// Difficulty label (e.g. `'beginner'`, `'advanced'`). Null when not specified.
  final String? difficulty;

  /// Taxonomy tags returned by the RPC (e.g. `['gluten-free', 'quick']`).
  final List<String> tags;

  /// Domain type slug that distinguishes specialised recipe kinds
  /// (e.g. `'pizza'`, `'smoking'`). Null when not specified.
  final String? domainType;

  const RagQueryResult({
    required this.name,
    required this.courseLabel,
    required this.isFavourite,
    required this.cookCount,
    required this.isMemoix,
    required this.similarityScore,
    this.lastCookedAt,
    this.time,
    this.isPitNote = false,
    this.cuisine,
    this.ingredientNames = const [],
    this.region,
    this.technique,
    this.difficulty,
    this.tags = const [],
    this.domainType,
  });

  /// Deserialises a [RagQueryResult] from a Supabase response row.
  ///
  /// Expects snake_case keys as returned by a Postgres function or RPC call.
  factory RagQueryResult.fromJson(Map<String, dynamic> json) {
    return RagQueryResult(
      name: json['name'] as String,
      courseLabel: json['course_label'] as String,
      isFavourite: json['is_favourite'] as bool? ?? false,
      cookCount: json['cook_count'] as int? ?? 0,
      lastCookedAt: json['last_cooked_at'] != null
          ? DateTime.parse(json['last_cooked_at'] as String)
          : null,
      isMemoix: json['is_memoix'] as bool? ?? false,
      time: json['time'] as String?,
      isPitNote: json['is_pit_note'] as bool? ?? false,
      cuisine: json['cuisine'] as String?,
      ingredientNames: (json['ingredient_names'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      region: json['region'] as String?,
      technique: json['technique'] as String?,
      difficulty: json['difficulty'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      domainType: json['domain_type'] as String?,
    );
  }
}
