import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/database/app_database.dart';
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
  final int daysSinceCooked = c.lastCookedAt != null 
      ? DateTime.now().difference(c.lastCookedAt!).inDays 
      : 90;

  final bool lowRecency = daysSinceCooked >= 14;
  final bool isHighlyRecent = daysSinceCooked <= 4; // Cooked in the last 4 days

  int score;
  
  // Circuit Breaker: If we just ate this, tank the score so it only 
  // surfaces if the pool is incredibly small.
  if (isHighlyRecent) {
    score = 1; 
  } else if (c.isMemoix) {
    score = (c.isFavourite || c.cookCount > 0) ? 2 : 1;
  } else if (c.cookCount >= 3 && lowRecency) {
    score = 7;
  } else if (c.isFavourite && lowRecency) {
    score = 6;
  } else if (c.isFavourite) {
    score = 5;
  } else if (c.cookCount > 0) {
    score = 4;
  } else {
    score = 3;
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
  // 1. Bucket and shuffle within tiers
  final Map<int, List<_OmniCandidate>> byScore = {};
  for (final c in pool) {
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

  OmnibarDelegate(this.ref);

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
    return _OmniResultsView(
      query: query,
      onClose: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
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

    final rng = Random(DateTime.now().millisecondsSinceEpoch);
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
