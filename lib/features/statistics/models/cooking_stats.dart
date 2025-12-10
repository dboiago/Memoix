import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

part 'cooking_stats.g.dart';

/// Tracks when a user cooks a recipe
@collection
class CookingLog {
  Id id = Isar.autoIncrement;

  @Index()
  late String recipeId;

  late String recipeName;
  late String? recipeCourse;
  late String? recipeCuisine;

  @Index()
  late DateTime cookedAt;

  /// Optional notes about this cooking session
  String? notes;

  /// Servings made (may differ from recipe default)
  int? servingsMade;

  CookingLog();

  CookingLog.create({
    required this.recipeId,
    required this.recipeName,
    this.recipeCourse,
    this.recipeCuisine,
    DateTime? cookedAt,
    this.notes,
    this.servingsMade,
  }) : cookedAt = cookedAt ?? DateTime.now();
}

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

  const CookingStats({
    required this.totalCooks,
    required this.uniqueRecipes,
    required this.recipesThisMonth,
    required this.cooksThisMonth,
    required this.cooksByCourse,
    required this.cooksByCuisine,
    required this.topRecipes,
    required this.recentCooks,
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
  final Isar _db;

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
    final log = CookingLog.create(
      recipeId: recipeId,
      recipeName: recipeName,
      recipeCourse: course,
      recipeCuisine: cuisine,
      servingsMade: servings,
      notes: notes,
    );

    await _db.writeTxn(() => _db.cookingLogs.put(log));
  }

  /// Get cook count for a specific recipe
  Future<int> getCookCount(String recipeId) async {
    return await _db.cookingLogs
        .where()
        .recipeIdEqualTo(recipeId)
        .count();
  }

  /// Get last cook date for a recipe
  Future<DateTime?> getLastCookDate(String recipeId) async {
    final logs = await _db.cookingLogs
        .where()
        .recipeIdEqualTo(recipeId)
        .sortByCookedAtDesc()
        .limit(1)
        .findAll();

    return logs.isNotEmpty ? logs.first.cookedAt : null;
  }

  /// Get aggregated statistics
  Future<CookingStats> getStats() async {
    final allLogs = await _db.cookingLogs.where().findAll();

    if (allLogs.isEmpty) return CookingStats.empty;

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
            ))
        .toList()
      ..sort((a, b) => b.cookCount.compareTo(a.cookCount));

    // Recent cooks
    final recentLogs = await _db.cookingLogs
        .where()
        .sortByCookedAtDesc()
        .limit(10)
        .findAll();

    return CookingStats(
      totalCooks: allLogs.length,
      uniqueRecipes: uniqueRecipeIds.length,
      recipesThisMonth: thisMonthRecipeIds.length,
      cooksThisMonth: cooksThisMonth,
      cooksByCourse: cooksByCourse,
      cooksByCuisine: cooksByCuisine,
      topRecipes: topRecipes.take(10).toList(),
      recentCooks: recentLogs,
    );
  }

  /// Watch stats changes
  Stream<void> watchChanges() {
    return _db.cookingLogs.watchLazy();
  }

  /// Delete a cooking log
  Future<void> deleteLog(int logId) async {
    await _db.writeTxn(() => _db.cookingLogs.delete(logId));
  }
}

// Providers
final cookingStatsServiceProvider = Provider<CookingStatsService>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final cookingStatsProvider = FutureProvider<CookingStats>((ref) async {
  final service = ref.watch(cookingStatsServiceProvider);
  return service.getStats();
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
