import '../../recipes/models/continent_mapping.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/cuisine.dart';

enum OmniQueryType { suggestion, collection }

/// Meal-time context extracted from a free-form query.
enum MealContext {
  general, breakfast, lunch, dinner, dessert,
  drink, bread, cheese, cellar, snack, charcuterie
}

class OmniQueryClassification {
  final OmniQueryType type;
  /// Title-cased cuisine terms detected in the query (e.g. ['Italian', 'South African']).
  final List<String>? detectedCuisines;
  final String? detectedCourse;
  final String? detectedIngredient;
  final int? maxTimeMinutes;
  final bool wantsUntried;
  final MealContext mealContext;
  /// Soft course hints derived from vibe markers. Not a hard filter.
  final List<String> preferredCourses;
  /// True when the query signals the user has time for a long project.
  final bool prefersLongProject;
  /// Cuisine to hard-exclude, extracted from aversion phrases (e.g. "sick of Italian").
  final String? excludeCuisine;

  const OmniQueryClassification({
    required this.type,
    this.detectedCuisines,
    this.detectedCourse,
    this.detectedIngredient,
    this.maxTimeMinutes,
    this.wantsUntried = false,
    this.mealContext = MealContext.general,
    this.preferredCourses = const [],
    this.prefersLongProject = false,
    this.excludeCuisine,
  });

  /// Lowercased cuisine list for RPC filter_cuisine calls.
  List<String>? get cuisinesForFilter =>
      detectedCuisines?.map((c) => c.toLowerCase()).toList();

  /// True when no structured SQL signals can be derived from this classification.
  /// Used to detect vibe queries that cannot be meaningfully served without a
  /// provider key.
  bool get isUnmappable =>
      preferredCourses.isEmpty &&
      !prefersLongProject &&
      excludeCuisine == null &&
      (detectedCuisines == null || detectedCuisines!.isEmpty) &&
      detectedCourse == null &&
      detectedIngredient == null &&
      maxTimeMinutes == null;
}

abstract class OmniQueryClassifier {
  OmniQueryClassification classify(String query);
}

class HeuristicQueryClassifier implements OmniQueryClassifier {
  const HeuristicQueryClassifier();

  static const List<String> _vibeMarkers = [
    'comfort', 'heavy', 'light', 'fresh', 'warm', 'rainy', 'weekend',
    'cozy', 'sick of', 'tired of', 'nothing', 'avoid',
  ];

  static const List<String> _suggestionMarkers = [
    'something', 'recommend', 'feel like', 'pick', 'surprise',
  ];

  static const List<String> _collectionMarkers = [
    'show me', 'list', 'browse', 'recipes', 'dishes',
  ];

  static const List<String> _mealContextWords = [
    'dinner', 'lunch', 'breakfast', 'brunch', 'snack', 'supper',
    'tonight', 'today', 'quick', 'easy', 'charcuterie',
  ];

  @override
  OmniQueryClassification classify(String query) {
    final q = query.toLowerCase();

    // Pre-compute intent fields from a single pass over the query.
    final mealCtx = _extractMeal(q);
    final rawTime = _extractTime(q);
    // Apply meal-context time defaults when no explicit time is present.
    int? resolvedTime = rawTime;
    if (resolvedTime == null) {
      if (mealCtx == MealContext.lunch)      resolvedTime = 40;
      if (mealCtx == MealContext.breakfast)  resolvedTime = 30;
      if (mealCtx == MealContext.snack)      resolvedTime = 15;
    }
    final ingredient = _extractIngredient(q);
    final untried = _extractUntried(q);
    final preferredCourses = _extractPreferredCourses(q);
    final prefersLongProject = _extractPrefersLongProject(q);
    final excludeCuisine = _extractExcludeCuisine(q);

    final (:cuisine, :course, :matchCount) = _scanTaxonomy(q);

    // Step 0: Cuisine-browse intent.
    // Collect ALL cuisine terms from ContinentMapping that match word boundaries.
    // If at least one matches and no meal-context word is present, return a
    // browse/collection result immediately.
    final List<String> matchedCuisines = [];
    for (final key in ContinentMapping.cuisineToCountry.keys) {
      if (_matchesBoundary(q, key)) {
        matchedCuisines.add(_toTitleCase(key));
      }
    }
    if (matchedCuisines.isNotEmpty &&
        !_mealContextWords.any((w) => _matchesBoundary(q, w))) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: matchedCuisines,
        detectedCourse: course,
        detectedIngredient: ingredient,
        maxTimeMinutes: resolvedTime,
        wantsUntried: untried,
        mealContext: mealCtx,
        preferredCourses: preferredCourses,
        prefersLongProject: prefersLongProject,
        excludeCuisine: excludeCuisine,
      );
    }

    // Step 1: Vibe/aversion markers → suggestion immediately.
    for (final marker in _vibeMarkers) {
      if (q.contains(marker)) {
        return OmniQueryClassification(
          type: OmniQueryType.suggestion,
          detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
          detectedCourse: course,
          detectedIngredient: ingredient,
          maxTimeMinutes: resolvedTime,
          wantsUntried: untried,
          mealContext: mealCtx,
          preferredCourses: preferredCourses,
          prefersLongProject: prefersLongProject,
          excludeCuisine: excludeCuisine,
        );
      }
    }

    // Step 2: Suggestion-intent markers → suggestion.
    // 'a ' uses trailing space to avoid matching mid-word substrings.
    if (q.contains('a ') || _suggestionMarkers.any(q.contains)) {
      return OmniQueryClassification(
        type: OmniQueryType.suggestion,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
        detectedIngredient: ingredient,
        maxTimeMinutes: resolvedTime,
        wantsUntried: untried,
        mealContext: mealCtx,
        preferredCourses: preferredCourses,
        prefersLongProject: prefersLongProject,
        excludeCuisine: excludeCuisine,
      );
    }

    // Step 3: Collection-intent markers → collection.
    // 'all' is matched as a whole word only.
    if (RegExp(r'\ball\b').hasMatch(q) || _collectionMarkers.any(q.contains)) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
        detectedIngredient: ingredient,
        maxTimeMinutes: resolvedTime,
        wantsUntried: untried,
        mealContext: mealCtx,
        preferredCourses: preferredCourses,
        prefersLongProject: prefersLongProject,
        excludeCuisine: excludeCuisine,
      );
    }

    // Step 4: Taxonomy count.
    // Exactly one distinct taxonomy value → collection with that value populated.
    // Two or more → suggestion with detected values populated where applicable.
    if (matchCount == 1) {
      return OmniQueryClassification(
        type: OmniQueryType.collection,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
        detectedIngredient: ingredient,
        maxTimeMinutes: resolvedTime,
        wantsUntried: untried,
        mealContext: mealCtx,
        preferredCourses: preferredCourses,
        prefersLongProject: prefersLongProject,
        excludeCuisine: excludeCuisine,
      );
    }
    if (matchCount >= 2) {
      return OmniQueryClassification(
        type: OmniQueryType.suggestion,
        detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
        detectedCourse: course,
        detectedIngredient: ingredient,
        maxTimeMinutes: resolvedTime,
        wantsUntried: untried,
        mealContext: mealCtx,
        preferredCourses: preferredCourses,
        prefersLongProject: prefersLongProject,
        excludeCuisine: excludeCuisine,
      );
    }

    // Step 5: Default → suggestion.
    return OmniQueryClassification(
      type: OmniQueryType.suggestion,
      detectedCuisines: cuisine != null ? [_toTitleCase(cuisine)] : null,
      detectedCourse: course,
      detectedIngredient: ingredient,
      maxTimeMinutes: resolvedTime,
      wantsUntried: untried,
      mealContext: mealCtx,
      preferredCourses: preferredCourses,
      prefersLongProject: prefersLongProject,
      excludeCuisine: excludeCuisine,
    );
  }

  MealContext _extractMeal(String q) {
    bool has(String pattern) =>
        RegExp(r'\b(' + pattern + r')\b', caseSensitive: false).hasMatch(q);

    if (has('dessert|sweets?|cake|cookies|pastry')) return MealContext.dessert;
    if (has('drinks?|wine|beer|cocktail|beverages?|thirsty')) return MealContext.drink;
    if (has('charcuterie|board')) return MealContext.charcuterie;
    if (has('cheese')) return MealContext.cheese;
    if (has('cellar')) return MealContext.cellar;
    if (has('bread|sourdough|bak(e|ing)|loaf')) return MealContext.bread;
    if (has('snacks?|nibble|munchies|munch')) return MealContext.snack;
    if (has('breakfast|morning|brunch')) return MealContext.breakfast;
    if (has('lunch|midday|afternoon')) return MealContext.lunch;
    if (has('dinner|tonight|supper|evening')) return MealContext.dinner;
    return MealContext.general;
  }

  int? _extractTime(String q) {
    final hrMatch = RegExp(r'(\d+)\s*h').firstMatch(q);
    final minMatch = RegExp(r'(\d+)\s*m').firstMatch(q);
    int total = 0;
    if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    return total > 0 ? total : null;
  }

  String? _extractIngredient(String q) {
    final m = RegExp(
        r'\b(?:with|use up|using|got)\s+([a-zA-Z]+)\b',
        caseSensitive: false).firstMatch(q);
    return m?.group(1);
  }

  bool _extractUntried(String q) =>
      RegExp(r'\b(untried|never made|new|test|backlog)\b',
          caseSensitive: false).hasMatch(q);

  ({String? cuisine, String? course, int matchCount}) _scanTaxonomy(String q) {
    String? firstCuisine;
    String? firstCourse;
    int matchCount = 0;

    for (final c in Cuisine.all) {
      if (_matchesBoundary(q, c.name.toLowerCase())) {
        firstCuisine ??= c.name;
        matchCount++;
      }
    }

    for (final c in Course.defaults) {
      final nameMatches = _matchesBoundary(q, c.name.toLowerCase());
      final slugMatches = _matchesBoundary(q, c.slug.toLowerCase());
      if (nameMatches || slugMatches) {
        firstCourse ??= c.slug;
        matchCount++;
      }
    }

    return (cuisine: firstCuisine, course: firstCourse, matchCount: matchCount);
  }

  bool _matchesBoundary(String text, String term) {
    if (term.isEmpty) return false;
    return RegExp(r'\b' + RegExp.escape(term) + r'\b').hasMatch(text);
  }

  static String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  List<String> _extractPreferredCourses(String q) {
    final courses = <String>{};
    if (_matchesBoundary(q, 'light') || _matchesBoundary(q, 'fresh') || _matchesBoundary(q, 'simple')) {
      courses.addAll(['soups', 'salad', 'sides']);
    }
    if (_matchesBoundary(q, 'cozy') || _matchesBoundary(q, 'comfort') ||
        _matchesBoundary(q, 'warm') || _matchesBoundary(q, 'hearty') || _matchesBoundary(q, 'rainy')) {
      courses.addAll(['mains', 'soups']);
    }
    if (_matchesBoundary(q, 'heavy') || _matchesBoundary(q, 'rich') || _matchesBoundary(q, 'indulgent')) {
      courses.addAll(['mains', 'desserts', 'smoking']);
    }
    return courses.toList();
  }

  bool _extractPrefersLongProject(String q) =>
      q.contains('long weekend') ||
      _matchesBoundary(q, 'project') ||
      q.contains('i have time') ||
      q.contains('day off') ||
      q.contains('taking my time');

  String? _extractExcludeCuisine(String q) {
    final m = RegExp(
      r'\b(?:sick of|tired of|avoid|no)\s+([a-z]+)\b',
      caseSensitive: false,
    ).firstMatch(q);
    return m?.group(1)?.trim().toLowerCase();
  }
}
