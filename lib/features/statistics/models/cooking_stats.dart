import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../smoking/repository/smoking_repository.dart';

/// Aggregated statistics
class CookingStats {
  final int totalCooks;
  final int uniqueRecipes;
  final int recipesThisMonth;
  final int cooksThisMonth;
  final Map<String, int> cooksByCourse;
  final Map<String, int> cooksByCuisine;
  final List<TopRecipe> topRecipes;
  final List<CookingLog> recentCooks;
  final int totalRecipes;
  final int distinctCuisineCount;
  final int? avgCookTimeMinutes;

  const CookingStats({
    required this.totalCooks,
    required this.uniqueRecipes,
    required this.recipesThisMonth,
    required this.cooksThisMonth,
    required this.cooksByCourse,
    required this.cooksByCuisine,
    required this.topRecipes,
    required this.recentCooks,
    required this.totalRecipes,
    required this.distinctCuisineCount,
    this.avgCookTimeMinutes,
  });

  static const empty = CookingStats(
    totalCooks: 0,
    uniqueRecipes: 0,
    recipesThisMonth: 0,
    cooksThisMonth: 0,
    cooksByCourse: {},
    cooksByCuisine: {},
    topRecipes: [],
    recentCooks: [],
    totalRecipes: 0,
    distinctCuisineCount: 0,
  );
}

class TopRecipe {
  final String recipeId;
  final String recipeName;
  final int cookCount;
  final DateTime lastCooked;

  const TopRecipe({
    required this.recipeId,
    required this.recipeName,
    required this.cookCount,
    required this.lastCooked,
  });
}

/// Service for tracking cooking statistics
class CookingStatsService {
  final AppDatabase _db;

  CookingStatsService(this._db);

  /// Log that a recipe was cooked
  Future<void> logCook({
    required String recipeId,
    required String recipeName,
    String? course,
    String? cuisine,
    int? servings,
    String? notes,
  }) async {
    final companion = CookingLogsCompanion(
      recipeId: Value(recipeId),
      recipeName: Value(recipeName),
      recipeCourse: Value(course),
      recipeCuisine: Value(cuisine),
      servingsMade: Value(servings),
      notes: Value(notes),
      cookedAt: Value(DateTime.now()),
    );
    await _db.cookingLogDao.logCook(companion);
  }

  /// Get cook count for a specific recipe
  Future<int> getCookCount(String recipeId) =>
      _db.cookingLogDao.getCookCount(recipeId);

  /// Get last cook date for a recipe
  Future<DateTime?> getLastCookDate(String recipeId) =>
      _db.cookingLogDao.getLastCookDate(recipeId);

  /// Get aggregated statistics
  Future<CookingStats> getStats() async {
    final allRecipes = await _db.recipeDao.getAllRecipes();
    final totalRecipes = allRecipes.length;

    final cuisineValues = <String>{};
    for (final r in allRecipes) {
      if (r.cuisine != null && r.cuisine!.trim().isNotEmpty) {
        cuisineValues.add(r.cuisine!.trim().toLowerCase());
      }
      if (r.country != null && r.country!.trim().isNotEmpty) {
        cuisineValues.add(r.country!.trim().toLowerCase());
      }
    }
    final distinctCuisineCount = cuisineValues.length;

    final timesInMinutes = allRecipes
        .map((r) => _parseTimeToMinutes(r.time))
        .whereType<int>()
        .toList();
    final int? avgCookTimeMinutes = timesInMinutes.isNotEmpty
        ? timesInMinutes.reduce((a, b) => a + b) ~/ timesInMinutes.length
        : null;

    final allLogs = await _db.cookingLogDao.getStats();

    if (allLogs.isEmpty) {
      return CookingStats(
        totalCooks: 0,
        uniqueRecipes: 0,
        recipesThisMonth: 0,
        cooksThisMonth: 0,
        cooksByCourse: {},
        cooksByCuisine: {},
        topRecipes: [],
        recentCooks: [],
        totalRecipes: totalRecipes,
        distinctCuisineCount: distinctCuisineCount,
        avgCookTimeMinutes: avgCookTimeMinutes,
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Calculate aggregates
    final uniqueRecipeIds = <String>{};
    final thisMonthRecipeIds = <String>{};
    final cooksByCourse = <String, int>{};
    final cooksByCuisine = <String, int>{};
    final recipeCountMap = <String, int>{};
    final recipeLastCook = <String, DateTime>{};
    final recipeNames = <String, String>{};
    var cooksThisMonth = 0;

    for (final log in allLogs) {
      uniqueRecipeIds.add(log.recipeId);
      recipeCountMap[log.recipeId] = (recipeCountMap[log.recipeId] ?? 0) + 1;
      recipeNames[log.recipeId] = log.recipeName;

      if (recipeLastCook[log.recipeId] == null ||
          log.cookedAt.isAfter(recipeLastCook[log.recipeId]!)) {
        recipeLastCook[log.recipeId] = log.cookedAt;
      }

      if (log.cookedAt.isAfter(startOfMonth)) {
        cooksThisMonth++;
        thisMonthRecipeIds.add(log.recipeId);
      }

      if (log.recipeCourse != null) {
        cooksByCourse[log.recipeCourse!] =
            (cooksByCourse[log.recipeCourse!] ?? 0) + 1;
      }

      if (log.recipeCuisine != null) {
        cooksByCuisine[log.recipeCuisine!] =
            (cooksByCuisine[log.recipeCuisine!] ?? 0) + 1;
      }
    }

    // Top recipes
    final topRecipes = recipeCountMap.entries
        .map((e) => TopRecipe(
              recipeId: e.key,
              recipeName: recipeNames[e.key] ?? 'Unknown',
              cookCount: e.value,
              lastCooked: recipeLastCook[e.key]!,
            ),)
        .toList()
      ..sort((a, b) => b.cookCount.compareTo(a.cookCount));

    // Recent cooks
    final recentLogs = await _db.cookingLogDao.getRecentStats();

    return CookingStats(
      totalCooks: allLogs.length,
      uniqueRecipes: uniqueRecipeIds.length,
      recipesThisMonth: thisMonthRecipeIds.length,
      cooksThisMonth: cooksThisMonth,
      cooksByCourse: cooksByCourse,
      cooksByCuisine: cooksByCuisine,
      topRecipes: topRecipes.take(10).toList(),
      recentCooks: recentLogs,
      totalRecipes: totalRecipes,
      distinctCuisineCount: distinctCuisineCount,
      avgCookTimeMinutes: avgCookTimeMinutes,
    );
  }

  static int? _parseTimeToMinutes(String? time) {
    if (time == null || time.trim().isEmpty) return null;
    final t = time.trim();
    final hoursMatch = RegExp(r'(\d+)\s*h').firstMatch(t);
    final minsMatch = RegExp(r'(\d+)\s*m(?!o)').firstMatch(t);
    final hours = hoursMatch != null ? int.tryParse(hoursMatch.group(1)!) ?? 0 : 0;
    final mins = minsMatch != null ? int.tryParse(minsMatch.group(1)!) ?? 0 : 0;
    final total = hours * 60 + mins;
    return total > 0 ? total : null;
  }

  /// Watch stats changes
  Stream<List<CookingLog>> watchChanges() {
    return _db.cookingLogDao.watchChanges();
  }

  /// Delete a cooking log
  Future<void> deleteLog(int logId) async {
    await _db.cookingLogDao.deleteLog(logId);
  }
}

// Providers
// Use central provider from core/providers.dart

final cookingStatsProvider = StreamProvider<CookingStats>((ref) {
  final service = ref.watch(cookingStatsServiceProvider);
  final db = ref.watch(databaseProvider);

  // ignore: close_sinks — closed in onDispose
  final controller = StreamController<CookingStats>.broadcast();

  Future<void> emit() async {
    try {
      controller.add(await service.getStats());
    } catch (e, st) {
      controller.addError(e, st);
    }
  }

  // Emit initial value immediately.
  emit();

  // Re-emit whenever cooking logs change (cook count, course, cuisine).
  final logSub = service.watchChanges().listen((_) => emit());

  // Re-emit whenever recipes change (total count, distinct cuisines, avg time).
  final recipeSub = db.recipeDao.watchAllRecipes().listen((_) => emit());

  ref.onDispose(() {
    logSub.cancel();
    recipeSub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Counts favourites across all item types, matching the Favourites screen.
final totalFavouriteCountProvider = Provider<AsyncValue<int>>((ref) {
  final recipes = ref.watch(favoriteRecipesProvider);
  final cheese = ref.watch(favoriteCheeseEntriesProvider);
  final cellar = ref.watch(favoriteCellarEntriesProvider);
  final pizzas = ref.watch(favoritePizzasProvider);
  final sandwiches = ref.watch(favoriteSandwichesProvider);
  final modernist = ref.watch(favoriteModernistRecipesProvider);
  final smoking = ref.watch(favoriteSmokingRecipesProvider);

  final all = [recipes, cheese, cellar, pizzas, sandwiches, modernist, smoking];
  if (all.any((a) => a.isLoading)) return const AsyncValue.loading();
  final errored = all.where((a) => a.hasError);
  if (errored.isNotEmpty) {
    return AsyncValue.error(errored.first.error!, errored.first.stackTrace!);
  }

  final count = (recipes.valueOrNull?.length ?? 0) +
      (cheese.valueOrNull?.length ?? 0) +
      (cellar.valueOrNull?.length ?? 0) +
      (pizzas.valueOrNull?.length ?? 0) +
      (sandwiches.valueOrNull?.length ?? 0) +
      (modernist.valueOrNull?.length ?? 0) +
      (smoking.valueOrNull?.length ?? 0);

  return AsyncValue.data(count);
});

final recipeCookCountProvider =
    FutureProvider.family<int, String>((ref, recipeId) async {
  final service = ref.watch(cookingStatsServiceProvider);
  return service.getCookCount(recipeId);
});

final recipeLastCookProvider =
    FutureProvider.family<DateTime?, String>((ref, recipeId) async {
  final service = ref.watch(cookingStatsServiceProvider);
  return service.getLastCookDate(recipeId);
});
