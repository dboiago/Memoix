import 'dart:async';
import 'dart:ui' show VoidCallback;
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';

/// Helper class for pending delete data
class _PendingDelete {
  final DateTime date;
  final String instanceId; // Target unique ID
  
  _PendingDelete({required this.date, required this.instanceId});
}



/// Weekly meal plan view model
class WeeklyPlan {
  final DateTime weekStart;
  final Map<String, MealPlan> dailyPlans; // date string -> plan
  final Map<String, List<PlannedMeal>> meals; // date string -> meals

  WeeklyPlan({
    required this.weekStart,
    required this.dailyPlans,
    required this.meals,
  });

  /// Get the plan for a specific day of the week (0 = Monday)
  MealPlan? planForDay(int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex));
    final dateStr = _formatDate(date);
    return dailyPlans[dateStr];
  }

  /// Get meals for a specific day of the week (0 = Monday)
  List<PlannedMeal> mealsForDay(int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex));
    final dateStr = _formatDate(date);
    return meals[dateStr] ?? [];
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get all recipe IDs in this week's plan
  Set<String> get allRecipeIds {
    final ids = <String>{};
    for (final mealList in meals.values) {
      for (final meal in mealList) {
        if (meal.recipeId != null) {
          ids.add(meal.recipeId!);
        }
      }
    }
    return ids;
  }
}

/// Meal courses for the day
class MealCourse {
  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String snack = 'snack';

  static const List<String> all = [breakfast, lunch, dinner, snack];

  static String displayName(String course) {
    switch (course) {
      case breakfast:
        return 'Breakfast';
      case lunch:
        return 'Lunch';
      case dinner:
        return 'Dinner';
      case snack:
        return 'Snack';
      default:
        return course;
    }
  }

  static String emoji(String course) {
    return '';
  }
}

/// Service for managing meal plans
class MealPlanService {
  final AppDatabase _db;
  
  // Track pending deletes by instanceId (unique) instead of fuzzy keys
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, _PendingDelete> _pendingDeleteData = {};

  MealPlanService(this._db);
  
  /// Schedule a meal for deletion with undo capability
  void scheduleMealDelete({
    required DateTime date,
    required String instanceId, // Target unique ID
    required Duration undoDuration,
    VoidCallback? onComplete,
  }) {
    // Key is simply the instanceId (it's unique globally)
    final key = instanceId;
    
    // Cancel any existing pending delete for this key
    _pendingDeletes[key]?.cancel();
    
    // Store the delete data
    _pendingDeleteData[key] = _PendingDelete(date: date, instanceId: instanceId);
    
    // Start timer
    _pendingDeletes[key] = Timer(undoDuration, () async {
      final data = _pendingDeleteData.remove(key);
      _pendingDeletes.remove(key);
      if (data != null) {
        await removeMeal(data.date, data.instanceId);
        onComplete?.call();
      }
    });
  }
  
  /// Cancel a pending delete (undo)
  void cancelPendingDelete(String instanceId) {
    _pendingDeletes[instanceId]?.cancel();
    _pendingDeletes.remove(instanceId);
    _pendingDeleteData.remove(instanceId);
  }
  
  /// Check if a delete is pending for this ID
  bool isPendingDelete(String instanceId) => _pendingDeletes.containsKey(instanceId);
  
  /// Execute all pending deletes immediately (call on navigation away)
  Future<void> flushPendingDeletes() async {
    final entries = Map<String, _PendingDelete>.from(_pendingDeleteData);
    for (final entry in _pendingDeletes.values) {
      entry.cancel();
    }
    _pendingDeletes.clear();
    _pendingDeleteData.clear();
    
    for (final data in entries.values) {
      await removeMeal(data.date, data.instanceId);
    }
  }

  /// Get or create a plan for a specific date
  Future<MealPlan> getOrCreate(DateTime date) =>
      _db.mealPlanDao.getOrCreatePlan(_formatDate(date));

  /// Add a meal to a specific date
  Future<void> addMeal(
    DateTime date, {
    required String recipeId,
    required String recipeName,
    required String course,
    int? servings,
    String? notes,
    String? cuisine,
    String? recipeCategory,
  }) async {
    final plan = await getOrCreate(date);
    await _db.mealPlanDao.addMeal(PlannedMealsCompanion.insert(
      mealPlanId: plan.id,
      instanceId: const Uuid().v4(),
      recipeId: Value(recipeId),
      recipeName: Value(recipeName),
      course: Value(course),
      servings: Value(servings),
      notes: Value(notes),
      cuisine: Value(cuisine),
      recipeCategory: Value(recipeCategory),
    ),);
  }

  /// Remove a meal by unique Instance ID
  Future<void> removeMeal(DateTime date, String instanceId) =>
      _db.mealPlanDao.removeMeal(instanceId);

  /// Move a meal from one date to another
  Future<void> moveMeal(
    DateTime fromDate,
    String instanceId,
    DateTime toDate,
    String newCourse,
  ) async {
    final meal = await _db.mealPlanDao.getMealByInstanceId(instanceId);
    if (meal == null) return;
    final toPlan = await _db.mealPlanDao.getOrCreatePlan(_formatDate(toDate));
    await _db.mealPlanDao.removeMeal(instanceId);
    await _db.mealPlanDao.addMeal(PlannedMealsCompanion.insert(
      mealPlanId: toPlan.id,
      instanceId: meal.instanceId,
      recipeId: Value(meal.recipeId),
      recipeName: Value(meal.recipeName),
      course: Value(newCourse),
      notes: Value(meal.notes),
      servings: Value(meal.servings),
      cuisine: Value(meal.cuisine),
      recipeCategory: Value(meal.recipeCategory),
    ),);
  }

  /// Get a week's worth of plans
  Future<WeeklyPlan> getWeek(DateTime weekStart) async {
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));
    final dates = List.generate(7, (i) => _formatDate(monday.add(Duration(days: i))));
    final plansList = await _db.mealPlanDao.getWeekPlans(dates);
    final plans = <String, MealPlan>{};
    final mealsMap = <String, List<PlannedMeal>>{};
    for (final plan in plansList) {
      plans[plan.date] = plan;
      mealsMap[plan.date] = await _db.mealPlanDao.getMealsForPlan(plan.id);
    }
    return WeeklyPlan(weekStart: monday, dailyPlans: plans, meals: mealsMap);
  }

  /// Watch plans for a date range
  Stream<List<MealPlan>> watchDateRange(DateTime start, DateTime end) =>
      _db.mealPlanDao.watchDateRange(_formatDate(start), _formatDate(end));

  /// Clear all meals for a date
  Future<void> clearDay(DateTime date) =>
      _db.mealPlanDao.clearDay(_formatDate(date));

  /// Copy a day's meals to another day
  Future<void> copyDay(DateTime from, DateTime to) =>
      _db.mealPlanDao.copyDay(_formatDate(from), _formatDate(to));

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Riverpod providers

// Use central provider from core/providers.dart

final weeklyPlanProvider = FutureProvider.family<WeeklyPlan, DateTime>((ref, weekStart) async {
  final service = ref.watch(mealPlanServiceProvider);
  return service.getWeek(weekStart);
});

final selectedWeekProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  // Start of current week (Monday)
  return now.subtract(Duration(days: now.weekday - 1));
});