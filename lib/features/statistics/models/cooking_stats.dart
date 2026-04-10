import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';

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
  final int favouriteCount;

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
    required this.favouriteCount,
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
    favouriteCount: 0,
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
    final favouriteCount = allRecipes.where((r) => r.isFavorite).length;

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
        favouriteCount: favouriteCount,
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
      favouriteCount: favouriteCount,
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

final cookingStatsProvider = StreamProvider<CookingStats>((ref) async* {
  final service = ref.watch(cookingStatsServiceProvider);
  
  // Emit initial stats
  yield await service.getStats();
  
  // Watch for changes and re-emit stats
  await for (final _ in service.watchChanges()) {
    yield await service.getStats();
  }
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
