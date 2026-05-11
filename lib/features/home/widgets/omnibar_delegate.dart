import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_shell.dart';
import '../../../app/routes/router.dart';
import '../../../shared/widgets/course_card.dart';
import '../../rag/models/rag_query_result.dart';
import '../../rag/services/omni_query_classifier.dart';
import '../../rag/services/rag_retrieval_service.dart';
import '../../recipes/models/course.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import '../../../core/database/app_database.dart' hide Recipe, Course;
import '../../cellar/models/cellar_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../recipes/models/cuisine.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reason line constants
// ─────────────────────────────────────────────────────────────────────────────

class OmnibarReasonLines {
  OmnibarReasonLines._();

  static const String highCookLowRecency1 = "You used to make this all the time.";
  static const String highCookLowRecency2 = "This one's been waiting.";

  static const String favouritedLowRecency1 = "A favourite you haven't touched in a while.";
  static const String favouritedLowRecency2 = "Marked as a favourite. Apparently forgotten.";

  static const String favouritedNeverCooked1 = "You liked the idea of this one.";
  static const String favouritedNeverCooked2 = "Saved for a reason. Presumably.";

  static const String cookedOnceAgo1 = "You made this once. Could be worth revisiting.";
  static const String cookedOnceAgo2 = "Made this before. Results unclear.";

  static const String noCookNoFavourite = "No strong opinion on this one. Could be worse.";

  static const String memoixDefault1 = "Try a Memoix recipe.";
  static const String memoixDefault2 = "Your library is quiet. Here's a starting point.";

  static const String frozenGrapes = "Frozen grapes.";
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal types
// ─────────────────────────────────────────────────────────────────────────────

enum _MealContext { 
  general, breakfast, lunch, dinner, dessert, 
  drink, bread, cheese, cellar, snack, charcuterie 
}

class _OmniCandidate {
  final String name;
  final String courseLabel;
  final bool isFavourite;
  final int cookCount;
  final DateTime? lastCookedAt;
  final bool isMemoix;
  final String? time;
  final bool isPitNote;
  final String? cuisine;
  final List<String> ingredientNames;
  final void Function(BuildContext) navigate;

  _OmniCandidate({
    required this.name,
    required this.courseLabel,
    required this.isFavourite,
    required this.cookCount,
    required this.isMemoix,
    required this.navigate,
    this.lastCookedAt,
    this.time,
    this.isPitNote = false,
    this.cuisine,
    this.ingredientNames = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Omni query
// ─────────────────────────────────────────────────────────────────────────────

class _OmniQuery {
  final _MealContext meal;
  final String? cuisine;
  final String? useIngredient;
  final int? maxTimeMinutes;
  final bool wantsUntried;

  const _OmniQuery({
    this.meal = _MealContext.general,
    this.cuisine,
    this.useIngredient,
    this.maxTimeMinutes,
    this.wantsUntried = false,
  });

  bool get isGeneral =>
      meal == _MealContext.general &&
      cuisine == null &&
      useIngredient == null &&
      maxTimeMinutes == null &&
      !wantsUntried;
}

// ─────────────────────────────────────────────────────────────────────────────
// Intent parsing
// ─────────────────────────────────────────────────────────────────────────────

int? _extractTime(String q) {
  final hrMatch = RegExp(r'(\d+)\s*h').firstMatch(q);
  final minMatch = RegExp(r'(\d+)\s*m').firstMatch(q);
  int total = 0;
  if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
  if (minMatch != null) total += int.parse(minMatch.group(1)!);
  return total > 0 ? total : null;
}

bool _extractUntried(String q) =>
    RegExp(r'\b(untried|never made|new|test|backlog)\b',
        caseSensitive: false).hasMatch(q);

String? _extractIngredient(String q) {
  final m = RegExp(
      r'\b(?:with|use up|using|got)\s+([a-zA-Z]+)\b',
      caseSensitive: false).firstMatch(q);
  return m?.group(1);
}

String? _extractCuisine(String q, List<String> cuisines) {
  for (final name in cuisines) {
    if (RegExp(r'\b' + RegExp.escape(name) + r'\b',
        caseSensitive: false).hasMatch(q)) {
      return name;
    }
  }
  return null;
}

_MealContext _extractMeal(String q) {
  bool has(String pattern) =>
      RegExp(r'\b(' + pattern + r')\b', caseSensitive: false).hasMatch(q);

  if (has('dessert|sweets?|cake|cookies|pastry')) return _MealContext.dessert;
  if (has('drinks?|wine|beer|cocktail|beverages?|thirsty')) return _MealContext.drink;
  if (has('charcuterie|board')) return _MealContext.charcuterie;
  if (has('cheese')) return _MealContext.cheese;
  if (has('cellar')) return _MealContext.cellar;
  if (has('bread|sourdough|bak(e|ing)|loaf')) return _MealContext.bread;
  if (has('snacks?|nibble|munchies|munch')) return _MealContext.snack;
  if (has('breakfast|morning|brunch')) return _MealContext.breakfast;
  if (has('lunch|midday|afternoon')) return _MealContext.lunch;
  if (has('dinner|tonight|supper|evening')) return _MealContext.dinner;
  return _MealContext.general;
}

_OmniQuery _parseIntent(String query) {
  final q = query.replaceAll(RegExp(r'[^\w\s]'), '');
  final cuisineNames = Cuisine.all.map((c) => c.name).toList();

  final mealContext = _extractMeal(q);
  final explicitTime = _extractTime(q);

  // Inject defaults to prevent "meatloaf for lunch"
  int? resolvedTime = explicitTime;
  if (resolvedTime == null) {
    if (mealContext == _MealContext.lunch) resolvedTime = 40;
    if (mealContext == _MealContext.breakfast) resolvedTime = 30;
    if (mealContext == _MealContext.snack) resolvedTime = 15;
  }

  return _OmniQuery(
    meal: _extractMeal(q),
    cuisine: _extractCuisine(q, cuisineNames),
    useIngredient: _extractIngredient(q),
    maxTimeMinutes: _extractTime(q),
    wantsUntried: _extractUntried(q),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// Course eligibility
// ─────────────────────────────────────────────────────────────────────────────

const Set<String> _neverSuggestCourses = {'sauces', 'rubs', 'scratch', 'cellar', 'cheese'};

const Set<String> _generalOnlyCourses = {'pickles', 'salad', 'sides', 'apps'};

const Set<String> _generalAndMealCourses = {'mains', 'soups', 'soup', 'brunch', 'vegn', 'sandwiches'};

// Affinity map: for each non-general context, the exact recipe course slugs
// that are eligible. Domains (pizzas, smoking, modernist) are included for
// completeness but are gated by their own functions, not _isCourseEligible().
const Map<_MealContext, Set<String>> _mealContextCourses = {
  _MealContext.breakfast: {'brunch'},
  _MealContext.lunch: {'mains', 'soups', 'soup', 'sandwiches', 'salad', 'sides'},
  _MealContext.dinner: {'mains', 'soups', 'soup', 'sandwiches', 'pizzas', 'smoking',
                        'modernist', 'vegn', 'sides', 'salad'},
  _MealContext.dessert: {'desserts'},
  _MealContext.bread: {'breads'},
  _MealContext.drink: {'drinks'},
  _MealContext.cheese: {'cheese'},
  _MealContext.cellar: {'cellar'},
  _MealContext.snack: {'apps', 'sides', 'salads', 'pickles', 'sandwiches'},
  _MealContext.charcuterie: {'cheese', 'pickles'},
};

bool _isCourseEligible(String course, _MealContext context) {
  final slug = course.toLowerCase();
  if (_neverSuggestCourses.contains(slug)) return false;

  if (context == _MealContext.general) {
    return _generalAndMealCourses.contains(slug) || _generalOnlyCourses.contains(slug);
  }

  final allowed = _mealContextCourses[context];
  if (allowed == null) return false;
  return allowed.contains(slug);
}

bool _isSmokingEligible(_MealContext context, {required bool isPitNote}) {
  switch (context) {
    case _MealContext.general:
      return true;
    case _MealContext.breakfast:
    case _MealContext.lunch:
    case _MealContext.dinner:
      return !isPitNote;
    case _MealContext.dessert:
    case _MealContext.drink:
    case _MealContext.bread:
    case _MealContext.cheese:
    case _MealContext.cellar:
    case _MealContext.snack:
    case _MealContext.charcuterie:
      return false;
  }
}

bool _isModernistEligible(_MealContext context, {required bool isTechnique}) {
  switch (context) {
    case _MealContext.general:
      return true;
    case _MealContext.breakfast:
    case _MealContext.lunch:
    case _MealContext.dinner:
      return !isTechnique;
    case _MealContext.dessert:
    case _MealContext.drink:
    case _MealContext.bread:
    case _MealContext.cheese:
    case _MealContext.cellar:
    case _MealContext.snack:
    case _MealContext.charcuterie:
      return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scoring
// ─────────────────────────────────────────────────────────────────────────────

int _scoreCandidate(_OmniCandidate c) {
  if (c.isMemoix) return 1;

  final double decayedCooks = c.lastCookedAt != null
      ? c.cookCount * exp(-DateTime.now().difference(c.lastCookedAt!).inDays / 60.0)
      : c.cookCount * 0.5;

  int score;
  if (decayedCooks >= 5.0) {
    score = 7;
  } else if (decayedCooks >= 3.0) {
    score = 6;
  } else if (decayedCooks >= 1.0) {
    score = 5;
  } else if (decayedCooks > 0) {
    score = 4;
  } else if (c.isFavourite) {
    score = 3;
  } else {
    score = 2;
  }

  if (c.isPitNote) score -= 1;

  return score;
}

int? _parseTimeMinutes(String? time) {
  if (time == null || time.isEmpty) return null;
  final t = time.toLowerCase();
  final hrMatch = RegExp(r'(\d+)\s*h').firstMatch(t);
  final minMatch = RegExp(r'(\d+)\s*m').firstMatch(t);
  int total = 0;
  if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
  if (minMatch != null) total += int.parse(minMatch.group(1)!);
  return total > 0 ? total : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reason line selection
// ─────────────────────────────────────────────────────────────────────────────

String _reasonLine(_OmniCandidate c) {
  final bool alternate = c.name.hashCode.isOdd;
  final bool lowRecency = c.lastCookedAt != null &&
      DateTime.now().difference(c.lastCookedAt!).inDays >= 14;

  if (c.isMemoix) {
    return alternate ? OmnibarReasonLines.memoixDefault2 : OmnibarReasonLines.memoixDefault1;
  }
  if (c.cookCount >= 3 && lowRecency) {
    return alternate ? OmnibarReasonLines.highCookLowRecency2 : OmnibarReasonLines.highCookLowRecency1;
  }
  if (c.isFavourite && lowRecency) {
    return alternate ? OmnibarReasonLines.favouritedLowRecency2 : OmnibarReasonLines.favouritedLowRecency1;
  }
  if (c.isFavourite && c.cookCount == 0) {
    return alternate ? OmnibarReasonLines.favouritedNeverCooked2 : OmnibarReasonLines.favouritedNeverCooked1;
  }
  if (c.isFavourite) {
    return alternate ? OmnibarReasonLines.favouritedLowRecency2 : OmnibarReasonLines.favouritedLowRecency1;
  }
  if (c.cookCount > 0) {
    return alternate ? OmnibarReasonLines.cookedOnceAgo2 : OmnibarReasonLines.cookedOnceAgo1;
  }
  return OmnibarReasonLines.noCookNoFavourite;
}

// ─────────────────────────────────────────────────────────────────────────────
// Candidate ranking & selection
// ─────────────────────────────────────────────────────────────────────────────

List<_OmniCandidate> _rankAndTake(List<_OmniCandidate> pool, Random rng) {
  // 0. Pre-sampling pass: cap large pools to 3 candidates per course so the
  //    top score tiers contain variety rather than being dominated by the
  //    most-populated courses.
  List<_OmniCandidate> workingPool = pool;
  if (pool.length > 20) {
    final byCourse = <String, List<_OmniCandidate>>{};
    for (final c in pool) {
      (byCourse[c.courseLabel] ??= []).add(c);
    }
    final presampleRng = Random();
    workingPool = [];
    for (final group in byCourse.values) {
      final shuffled = [...group]..shuffle(presampleRng);
      workingPool.addAll(shuffled.take(3));
    }
  }

  // 1. Bucket and shuffle within tiers
  final Map<int, List<_OmniCandidate>> byScore = {};
  for (final c in workingPool) {
    (byScore[_scoreCandidate(c)] ??= []).add(c);
  }
  for (final group in byScore.values) {
    group.shuffle(rng);
  }

  // 2. Flatten into a prioritized list
  final sortedScores = byScore.keys.toList()..sort((a, b) => b.compareTo(a));
  final sortedCandidates = <_OmniCandidate>[];
  for (final score in sortedScores) {
    sortedCandidates.addAll(byScore[score]!);
  }

  // 3. Diversity pass
  final result = <_OmniCandidate>[];
  final seenCourses = <String>{};
  final leftovers = <_OmniCandidate>[];

  for (final c in sortedCandidates) {
    final course = c.courseLabel;
    
    if (!seenCourses.contains(course)) {
      result.add(c);
      seenCourses.add(course);
      if (result.length == 4) break;
    } else {
      leftovers.add(c); // Save it in case we need fillers later
    }
  }

  // 4. The Fallback Pass
  // If we don't have enough diverse courses to hit 4, backfill from the leftovers.
  if (result.length < 4) {
    for (final c in leftovers) {
      result.add(c);
      if (result.length == 4) break;
    }
  }

  return result;
}

List<_OmniCandidate> _selectSuggestions(
  List<_OmniCandidate> eligible,
  List<_OmniCandidate> memoixEligible,
  Random rng,
  _OmniQuery omniQuery,
) {
  List<_OmniCandidate> _applyFilters(List<_OmniCandidate> pool) {
    var filtered = pool;
    if (omniQuery.cuisine != null) {
      filtered = filtered.where((c) =>
          c.cuisine != null &&
          c.cuisine!.toLowerCase() == omniQuery.cuisine!.toLowerCase()).toList();
    }
    if (omniQuery.useIngredient != null) {
      final target = omniQuery.useIngredient!.toLowerCase();
      filtered = filtered.where((c) =>
          c.ingredientNames.any((n) => n.toLowerCase().contains(target))).toList();
    }
    if (omniQuery.maxTimeMinutes != null) {
      filtered = filtered.where((c) {
        final mins = _parseTimeMinutes(c.time);
        return mins == null || mins <= omniQuery.maxTimeMinutes!;
      }).toList();
    }
    if (omniQuery.wantsUntried) {
      filtered = filtered.where((c) => c.cookCount == 0).toList();
    }
    return filtered;
  }

  final filteredEligible = _applyFilters(eligible);
  final filteredMemoix = _applyFilters(memoixEligible);
  if (filteredEligible.isNotEmpty) return _rankAndTake(filteredEligible, rng);
  if (filteredMemoix.isNotEmpty) return _rankAndTake(filteredMemoix, rng);
  return [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Date formatting
// ─────────────────────────────────────────────────────────────────────────────

String _formatLastCooked(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d).inDays;
  if (diff == 0) return 'Last cooked today';
  if (diff == 1) return 'Last cooked yesterday';
  if (diff < 7) return 'Last cooked $diff days ago';
  if (diff < 14) return 'Last cooked last week';
  if (diff < 30) return 'Last cooked ${(diff / 7).round()} weeks ago';
  if (diff < 60) return 'Last cooked last month';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return 'Last cooked ${months[d.month - 1]} ${d.day}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Display name helpers
// ─────────────────────────────────────────────────────────────────────────────

String _courseDisplayName(String slug) {
  const names = <String, String>{
    'mains': 'Mains',
    'soups': 'Soups',
    'soup': 'Soups',
    'desserts': 'Desserts',
    'drinks': 'Drinks',
    'breads': 'Breads',
    'apps': 'Appetisers',
    'sides': 'Sides',
    'salad': 'Salad',
    'brunch': 'Brunch',
    'vegn': "Veg'n",
    'pickles': 'Pickles',
    'sandwiches': 'Sandwiches',
    'modernist': 'Modernist',
    'smoking': 'Smoking',
    'pizzas': 'Pizza',
    'cheese': 'Cheese',
    'cellar': 'Cellar',
  };
  return names[slug.toLowerCase()] ?? slug;
}

// ─────────────────────────────────────────────────────────────────────────────
// Delegate
// ─────────────────────────────────────────────────────────────────────────────

class OmnibarDelegate extends SearchDelegate<void> {
  final WidgetRef ref;

  // ── RAG / classification state ──────────────────────────────────────────
  final _classifier = const HeuristicQueryClassifier();

  OmniQueryClassification _classification =
      const OmniQueryClassification(type: OmniQueryType.suggestion);
  final ValueNotifier<bool> _collectionModeNotifier = ValueNotifier(false);
  String _lastClassifiedQuery = '';

  OmnibarDelegate(this.ref);

  /// Re-runs classification only when the query has changed.
  void _reclassifyIfNeeded(String q) {
    if (q == _lastClassifiedQuery) return;
    _lastClassifiedQuery = q;
    if (q.trim().isEmpty) {
      _classification =
          const OmniQueryClassification(type: OmniQueryType.suggestion);
      _collectionModeNotifier.value = false;
      return;
    }
    _classification = _classifier.classify(q);
    _collectionModeNotifier.value =
        _classification.type == OmniQueryType.collection;
  }

  /// Flips the collection/suggestion mode via [ValueNotifier].
  void _toggleMode() {
    _collectionModeNotifier.value = !_collectionModeNotifier.value;
  }

  @override
  String get searchFieldLabel => 'Ask a question...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      IconButton(
        icon: const Icon(Icons.arrow_forward),
        onPressed: () => showResults(context),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    _reclassifyIfNeeded(query);
    return _RagResultsShell(
      query: query,
      classification: _classification,
      collectionModeNotifier: _collectionModeNotifier,
      onToggleMode: _toggleMode,
      onClose: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isNotEmpty) {
      _reclassifyIfNeeded(query);
      return _RagResultsShell(
        query: query,
        classification: _classification,
        collectionModeNotifier: _collectionModeNotifier,
        onToggleMode: _toggleMode,
        onClose: () => close(context, null),
      );
    }
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Try: what should I make, what should I make for dinner',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results view
// ─────────────────────────────────────────────────────────────────────────────

class _OmniResultsView extends ConsumerWidget {
  final String query;
  final VoidCallback onClose;

  const _OmniResultsView({
    required this.query,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'Try: what should I make, what should I make for dinner',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final omniQuery = _parseIntent(query);
    final intent = omniQuery.meal;

    final recipesAsync = ref.watch(allRecipesProvider);
    final pizzasAsync = ref.watch(allPizzasProvider);
    final sandwichesAsync = ref.watch(allSandwichesProvider);
    final smokingAsync = ref.watch(allSmokingRecipesProvider);
    final modernistAsync = ref.watch(allModernistRecipesProvider);
    final cheeseAsync = intent == _MealContext.cheese
        ? ref.watch(allCheeseEntriesProvider)
        : const AsyncData<List<CheeseEntry>>([]);
    final cellarAsync = intent == _MealContext.cellar
        ? ref.watch(allCellarEntriesProvider)
        : const AsyncData<List<CellarEntry>>([]);

    final isLoading = recipesAsync.isLoading ||
        pizzasAsync.isLoading ||
        sandwichesAsync.isLoading ||
        smokingAsync.isLoading ||
        modernistAsync.isLoading ||
        cheeseAsync.isLoading ||
        cellarAsync.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recipes = recipesAsync.valueOrNull ?? [];
    final pizzas = pizzasAsync.valueOrNull ?? [];
    final sandwiches = sandwichesAsync.valueOrNull ?? [];
    final smokingAll = smokingAsync.valueOrNull ?? [];
    final modernists = modernistAsync.valueOrNull ?? [];
    final cheeseEntries = cheeseAsync.valueOrNull ?? [];
    final cellarEntries = cellarAsync.valueOrNull ?? [];

    final eligible = <_OmniCandidate>[];
    final memoixEligible = <_OmniCandidate>[];

        void _addRecipes() {
        for (final r in recipes) {
            if (!_isCourseEligible(r.course, intent)) continue;
            if (r.course == 'modernist') {
                final isTechnique = r.modernistType == ModernistType.technique.name;
            if (!_isModernistEligible(intent, isTechnique: isTechnique)) continue;
            }
            if (r.course == 'smoking') {
                final isPitNote = r.smokingType == SmokingType.pitNote.name;
            if (!_isSmokingEligible(intent, isPitNote: isPitNote)) continue;
            }
        final isMemoix = r.source == RecipeSource.memoix;
        final candidate = _OmniCandidate(
          name: r.name,
          courseLabel: _courseDisplayName(r.course),
          isFavourite: r.isFavourite,
          cookCount: r.cookCount,
          lastCookedAt: r.lastCookedAt,
          isMemoix: isMemoix,
          time: r.time,
          cuisine: r.cuisine,
          ingredientNames: r.ingredients.map((i) => i.name).toList(),
          navigate: (ctx) => AppRoutes.toRecipeDetail(ctx, r.uuid),
        );
        if (isMemoix) {
          memoixEligible.add(candidate);
        } else {
          eligible.add(candidate);
        }
      }
    }

    void _addPizzas() {
      if (!_isCourseEligible('pizzas', intent)) return;
      for (final p in pizzas) {
        final isMemoix = p.source == PizzaSource.memoix.name;
        final candidate = _OmniCandidate(
          name: p.name,
          courseLabel: 'Pizza',
          isFavourite: p.isFavourite,
          cookCount: p.cookCount,
          isMemoix: isMemoix,
          ingredientNames: [...p.cheesesList, ...p.proteinsList, ...p.vegetablesList],
          navigate: (ctx) => AppRoutes.toPizzaDetail(ctx, p.uuid),
        );
        if (isMemoix) {
          memoixEligible.add(candidate);
        } else {
          eligible.add(candidate);
        }
      }
    }

    void _addSandwiches() {
      if (!_isCourseEligible('sandwiches', intent)) return;
      for (final s in sandwiches) {
        final isMemoix = s.source == SandwichSource.memoix.name;
        final candidate = _OmniCandidate(
          name: s.name,
          courseLabel: 'Sandwich',
          isFavourite: s.isFavourite,
          cookCount: s.cookCount,
          isMemoix: isMemoix,
          ingredientNames: [s.bread, ...s.proteinsList, ...s.vegetablesList, ...s.cheesesList, ...s.condimentsList],
          navigate: (ctx) => AppRoutes.toSandwichDetail(ctx, s.uuid),
        );
        if (isMemoix) {
          memoixEligible.add(candidate);
        } else {
          eligible.add(candidate);
        }
      }
    }

    void _addSmoking() {
    if (!_isCourseEligible('smoking', intent)) return;
    for (final sm in smokingAll) {
        final isPitNote = sm.type == SmokingType.pitNote.name;
        if (!_isSmokingEligible(intent, isPitNote: isPitNote)) continue;
        final isMemoix = sm.source == SmokingSource.memoix.name;
        final candidate = _OmniCandidate(
        name: sm.name,
        courseLabel: isPitNote ? 'Pit Note' : 'Smoking',
        isFavourite: sm.isFavourite,
        cookCount: sm.cookCount,
        isMemoix: isMemoix,
        time: sm.time.isNotEmpty ? sm.time : null,
        isPitNote: isPitNote,
        ingredientNames: sm.seasoningsList.map((s) => s.name).toList(),
        navigate: (ctx) => AppRoutes.toSmokingDetail(ctx, sm.uuid),
        );
        if (isMemoix) {
        memoixEligible.add(candidate);
        } else {
        eligible.add(candidate);
        }
    }
    }

    void _addModernist() {
    if (!_isCourseEligible('modernist', intent)) return;
    for (final m in modernists) {
        final isTechnique = m.type == ModernistType.technique;
        if (!_isModernistEligible(intent, isTechnique: isTechnique)) continue;
        final isMemoix = m.source == ModernistSource.memoix;
        final candidate = _OmniCandidate(
        name: m.name,
        courseLabel: 'Modernist',
        isFavourite: m.isFavourite,
        cookCount: m.cookCount,
        isMemoix: isMemoix,
        time: m.time,
        isPitNote: isTechnique,
        ingredientNames: m.ingredients.map((i) => i.name).toList(),
        navigate: (ctx) => AppRoutes.toModernistDetail(ctx, m.id),
        );
        if (isMemoix) {
        memoixEligible.add(candidate);
        } else {
        eligible.add(candidate);
        }
    }
    }

    void _addCheese() {
      if (intent != _MealContext.cheese) return;
      for (final c in cheeseEntries) {
        final isMemoix = c.source == CheeseSource.memoix.name;
        final candidate = _OmniCandidate(
          name: c.name,
          courseLabel: 'Cheese',
          isFavourite: c.isFavourite,
          cookCount: 0,
          isMemoix: isMemoix,
          ingredientNames: const [],
          navigate: (ctx) => AppRoutes.toCheeseDetail(ctx, c.uuid),
        );
        if (isMemoix) {
          memoixEligible.add(candidate);
        } else {
          eligible.add(candidate);
        }
      }
    }

    void _addCellar() {
      if (intent != _MealContext.cellar) return;
      for (final c in cellarEntries) {
        final isMemoix = c.source == CellarSource.memoix.name;
        final candidate = _OmniCandidate(
          name: c.name,
          courseLabel: 'Cellar',
          isFavourite: c.isFavourite,
          cookCount: 0,
          isMemoix: isMemoix,
          ingredientNames: const [],
          navigate: (ctx) => AppRoutes.toCellarDetail(ctx, c.uuid),
        );
        if (isMemoix) {
          memoixEligible.add(candidate);
        } else {
          eligible.add(candidate);
        }
      }
    }

    _addRecipes();
    _addPizzas();
    _addSandwiches();
    _addSmoking();
    _addModernist();
    _addCheese();
    _addCellar();

    final rng = Random();
    final selected = _selectSuggestions(eligible, memoixEligible, rng, omniQuery);

    if (selected.isEmpty) {
      final theme = Theme.of(context);
      if (!omniQuery.isGeneral) {
        final mealLabel = intent != _MealContext.general ? intent.name : 'matching';
        return Center(
          child: Text(
            'No $mealLabel recipes found matching that.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      if (intent == _MealContext.breakfast || intent == _MealContext.lunch || intent == _MealContext.dinner) {
        final label = intent == _MealContext.breakfast
            ? 'breakfast'
            : intent == _MealContext.lunch
                ? 'lunch'
                : 'dinner';
        return Center(
          child: Text(
            'No $label recipes saved yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      return _FrozenGrapesView();
    }

    return _SuggestionsLayout(
      candidates: selected,
      onClose: onClose,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frozen grapes view
// ─────────────────────────────────────────────────────────────────────────────

class _FrozenGrapesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        OmnibarReasonLines.frozenGrapes,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions layout
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionsLayout extends StatelessWidget {
  final List<_OmniCandidate> candidates;
  final VoidCallback onClose;

  const _SuggestionsLayout({
    required this.candidates,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = candidates.first;
    final fallbacks = candidates.skip(1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrimaryCard(candidate: primary, onClose: onClose),
              if (fallbacks.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Other options',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ...fallbacks.map(
                  (c) => _FallbackTile(candidate: c, onClose: onClose),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary result card
// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryCard extends StatelessWidget {
  final _OmniCandidate candidate;
  final VoidCallback onClose;

  const _PrimaryCard({required this.candidate, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatLastCooked(candidate.lastCookedAt);
    final reason = _reasonLine(candidate);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onClose();
          Future.microtask(() => candidate.navigate(context));
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.courseLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                candidate.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                reason,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback result tile
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackTile extends StatelessWidget {
  final _OmniCandidate candidate;
  final VoidCallback onClose;

  const _FallbackTile({required this.candidate, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatLastCooked(candidate.lastCookedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        onClose();
        Future.microtask(() => candidate.navigate(context));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  candidate.courseLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              candidate.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Walkin navigation helper
// ─────────────────────────────────────────────────────────────────────────────

/// Constructs a temporary [Recipe] from a [RagQueryResult] and navigates to
/// [RecipeDetailView] using the same CupertinoPageRoute mechanism as local
/// results. The recipe is not persisted until the user explicitly saves it.
void _navigateToWalkin(RagQueryResult result, VoidCallback onClose) {
  final recipe = Recipe.create(
    uuid: const Uuid().v4(),
    name: result.name,
    course: result.courseLabel,
    cuisine: result.cuisine,
    time: result.time,
    source: RecipeSource.walkin,
    isFavourite: result.isFavourite,
    cookCount: result.cookCount,
    lastCookedAt: result.lastCookedAt,
  );
  onClose();
  Future.microtask(() {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => RecipeDetailView(recipe: recipe),
      ),
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RAG results shell — toggle chip + content dispatch
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps the omnibar's result area to add the mode toggle chip and dispatch
/// between suggestion mode (local results + walkin section) and collection
/// mode (community corpus browse). All content is gated on
/// [memoixAvailableProvider]; when false the delegate behaves exactly as
/// before with no changes to output.
class _RagResultsShell extends ConsumerWidget {
  final String query;
  final OmniQueryClassification classification;
  final ValueNotifier<bool> collectionModeNotifier;
  final VoidCallback onToggleMode;
  final VoidCallback onClose;

  const _RagResultsShell({
    required this.query,
    required this.classification,
    required this.collectionModeNotifier,
    required this.onToggleMode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoixAvailable = ref.watch(memoixAvailableProvider);
    final theme = Theme.of(context);
    final showChip = memoixAvailable && query.trim().isNotEmpty;

    return ValueListenableBuilder<bool>(
      valueListenable: collectionModeNotifier,
      builder: (context, isCollectionMode, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showChip)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(isCollectionMode ? 'The Walk-in' : 'Saved Recipes'),
                    selected: isCollectionMode,
                    onSelected: (_) => onToggleMode(),
                    selectedColor: theme.colorScheme.secondaryContainer,
                    showCheckmark: false,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: isCollectionMode
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: (memoixAvailable && isCollectionMode)
                  ? _WalkinCollectionView(
                      query: query,
                      classification: classification,
                      onClose: onClose,
                    )
                  : _SuggestionWithWalkin(
                      query: query,
                      classification: classification,
                      memoixAvailable: memoixAvailable,
                      onClose: onClose,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion mode — local results + optional walkin section below
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionWithWalkin extends StatelessWidget {
  final String query;
  final OmniQueryClassification classification;
  final bool memoixAvailable;
  final VoidCallback onClose;

  const _SuggestionWithWalkin({
    required this.query,
    required this.classification,
    required this.memoixAvailable,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!memoixAvailable) {
      // Memoix not available — behave exactly as before.
      return _OmniResultsView(query: query, onClose: onClose);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _OmniResultsView(query: query, onClose: onClose)),
        _WalkinSection(query: query, classification: classification, onClose: onClose),
      ],
    );
  }
}

/// Fetches walkin RAG results and renders them as a capped bottom panel below
/// the local suggestion results. Collapses to nothing when there are no results.
class _WalkinSection extends ConsumerStatefulWidget {
  final String query;
  final OmniQueryClassification classification;
  final VoidCallback onClose;

  const _WalkinSection({required this.query, required this.classification, required this.onClose});

  @override
  ConsumerState<_WalkinSection> createState() => _WalkinSectionState();
}

class _WalkinSectionState extends ConsumerState<_WalkinSection> {
  Future<List<RagQueryResult>>? _future;
  String? _lastQuery;

  Future<List<RagQueryResult>> _resolve() {
    if (_future == null || _lastQuery != widget.query) {
      _lastQuery = widget.query;
      _future = ref.read(ragRetrievalServiceProvider).query(
        widget.query,
        cuisine: widget.classification.detectedCuisine,
        course: widget.classification.detectedCourse,
      );
    }
    return _future!;
  }

  @override
  void didUpdateWidget(_WalkinSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _future = null;
      _lastQuery = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<RagQueryResult>>(
      future: _resolve(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final results = snapshot.data!;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'From the community',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _WalkinResultTile(
                    result: results[i],
                    onClose: widget.onClose,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collection mode — broad (grouped by course) or specific (flat list)
// ─────────────────────────────────────────────────────────────────────────────

class _WalkinCollectionView extends ConsumerStatefulWidget {
  final String query;
  final OmniQueryClassification classification;
  final VoidCallback onClose;

  const _WalkinCollectionView({
    required this.query,
    required this.classification,
    required this.onClose,
  });

  @override
  ConsumerState<_WalkinCollectionView> createState() =>
      _WalkinCollectionViewState();
}

class _WalkinCollectionViewState extends ConsumerState<_WalkinCollectionView> {
  Future<List<RagQueryResult>>? _future;
  String? _lastQuery;
  bool _showAll = false;
  String? _selectedCourse;

  static const int _showMoreThreshold = 5;

  Future<List<RagQueryResult>> _resolve() {
    if (_future == null || _lastQuery != widget.query) {
      _lastQuery = widget.query;
      _future = ref
          .read(ragRetrievalServiceProvider)
          .query(
            widget.query,
            limit: 20,
            cuisine: widget.classification.detectedCuisine,
            course: widget.classification.detectedCourse,
          );
    }
    return _future!;
  }

  /// True when exactly one of cuisine/course is detected (broad query).
  bool get _isBroad {
    final hasCuisine = widget.classification.detectedCuisine != null;
    final hasCourse = widget.classification.detectedCourse != null;
    return hasCuisine ^ hasCourse;
  }

  @override
  void didUpdateWidget(_WalkinCollectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _future = null;
      _lastQuery = null;
      _showAll = false;
      _selectedCourse = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTaxonomy = widget.classification.detectedCuisine != null ||
        widget.classification.detectedCourse != null;

    // No taxonomy detected — fall back to local suggestion view.
    if (!hasTaxonomy) {
      return _OmniResultsView(query: widget.query, onClose: widget.onClose);
    }

    return FutureBuilder<List<RagQueryResult>>(
      future: _resolve(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          final theme = Theme.of(context);
          return Center(
            child: Text(
              'No community recipes found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final results = snapshot.data!;
        return _isBroad
            ? _buildBroadView(context, results)
            : _buildSpecificView(context, results);
      },
    );
  }

  /// Broad: one taxonomy detected — group results by course and show
  /// [CourseCard]s. Tapping a card drills into a flat result list for that
  /// course.
  Widget _buildBroadView(BuildContext context, List<RagQueryResult> results) {
    final theme = Theme.of(context);
    final Map<String, List<RagQueryResult>> grouped = {};
    for (final r in results) {
      (grouped[r.courseLabel] ??= []).add(r);
    }

    if (_selectedCourse != null) {
      final courseResults = grouped[_selectedCourse] ?? [];
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedCourse = null),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(
                    _courseDisplayName(_selectedCourse!),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 8),
                ...courseResults.map(
                  (r) => _WalkinResultTile(result: r, onClose: widget.onClose),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allCourses = Course.defaults;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Browse by course',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: grouped.entries.map((entry) {
                  final slug = entry.key;
                  final count = entry.value.length;
                  final course = allCourses.firstWhere(
                    (c) => c.slug == slug,
                    orElse: () => Course.create(
                      slug: slug,
                      name: _courseDisplayName(slug),
                      sortOrder: 99,
                      colorValue: 0xFF888888,
                    ),
                  );
                  return SizedBox(
                    width: 100,
                    height: 80,
                    child: CourseCard(
                      course: course,
                      recipeCount: count,
                      onTap: () => setState(() => _selectedCourse = slug),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Specific: two taxonomy parameters detected — flat list with show more.
  Widget _buildSpecificView(BuildContext context, List<RagQueryResult> results) {
    final theme = Theme.of(context);
    final visible = _showAll
        ? results
        : results.take(_showMoreThreshold).toList();
    final hasMore = !_showAll && results.length > _showMoreThreshold;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community recipes',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ...visible.map(
                (r) => _WalkinResultTile(result: r, onClose: widget.onClose),
              ),
              if (hasMore) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => setState(() => _showAll = true),
                  child: Text(
                    'Show ${results.length - _showMoreThreshold} more',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Walkin result tile — follows the existing _FallbackTile pattern
// ─────────────────────────────────────────────────────────────────────────────

class _WalkinResultTile extends StatelessWidget {
  final RagQueryResult result;
  final VoidCallback onClose;

  const _WalkinResultTile({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatLastCooked(result.lastCookedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _navigateToWalkin(result, onClose),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _courseDisplayName(result.courseLabel),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              result.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
