import 'dart:async';
import 'dart:ui' show VoidCallback;
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';

part 'meal_plan.g.dart';

/// Helper class for pending delete data
class _PendingDelete {
  final DateTime date;
  final String instanceId; // Changed from index to unique ID
  
  _PendingDelete({required this.date, required this.instanceId});
}

/// Represents a single planned meal
@embedded
class PlannedMeal {
  String? instanceId; // Unique ID for this specific meal instance
  String? recipeId;
  String? recipeName;
  String? course; 
  String? notes;
  int? servings;
  String? cuisine; 
  String? recipeCategory; 

  PlannedMeal();

  PlannedMeal.create({
    required this.recipeId,
    required this.recipeName,
    this.course,
    this.notes,
    this.servings,
    this.cuisine,
    this.recipeCategory,
    String? instanceId,
  }) : instanceId = instanceId ?? const Uuid().v4();
}

/// A meal plan for a specific date
@collection
class MealPlan {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String date; 

  late List<PlannedMeal> meals;

  MealPlan();

  MealPlan.create({
    required this.date,
    this.meals = const [],
  });

  /// Get meals by course
  List<PlannedMeal> getMeals(String course) {
    return meals.where((m) => m.course == course).toList();
  }

  /// Check if this day has any meals
  bool get isEmpty => meals.isEmpty;

  /// Total meals planned for this day
  int get mealCount => meals.length;
}

/// Weekly meal plan view model
class WeeklyPlan {
  final DateTime weekStart;
  final Map<String, MealPlan> dailyPlans; 

  WeeklyPlan({
    required this.weekStart,
    required this.dailyPlans,
  });

  /// Get the plan for a specific day of the week (0 = Monday)
  MealPlan? planForDay(int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex));
    final dateStr = _formatDate(date);
    return dailyPlans[dateStr];
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get all recipe IDs in this week's plan
  Set<String> get allRecipeIds {
    final ids = <String>{};
    for (final plan in dailyPlans.values) {
      for (final meal in plan.meals) {
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
      case breakfast: return 'Breakfast';
      case lunch: return 'Lunch';
      case dinner: return 'Dinner';
      case snack: return 'Snack';
      default: return course;
    }
  }

  static String emoji(String course) => '';
}

/// Service for managing meal plans
class MealPlanService {
  final Isar _db;
  
  // Track pending deletes by instanceId (unique) instead of fuzzy keys
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, _PendingDelete> _pendingDeleteData = {};

  MealPlanService(this._db);
  
  /// Helper: Ensure all meals in a plan have IDs (Migration fix)
  Future<void> _ensureInstanceIds(MealPlan plan) async {
    bool dirty = false;
    final updatedMeals = <PlannedMeal>[];
    
    for (final meal in plan.meals) {
      if (meal.instanceId == null) {
        meal.instanceId = const Uuid().v4();
        dirty = true;
      }
      updatedMeals.add(meal);
    }
    
    if (dirty) {
      plan.meals = updatedMeals;
      await _db.writeTxn(() => _db.mealPlans.put(plan));
    }
  }

  /// Schedule a meal for deletion with undo capability
  void scheduleMealDelete({
    required DateTime date,
    required String instanceId, // Target unique ID
    required Duration undoDuration,
    VoidCallback? onComplete,
  }) {
    // Key is simply the instanceId (it's unique globally)
    final key = instanceId;
    
    _pendingDeletes[key]?.cancel();
    
    _pendingDeleteData[key] = _PendingDelete(date: date, instanceId: instanceId);
    
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
  
  /// Execute all pending deletes immediately
  Future<void> flushPendingDeletes() async {
    final entries = Map<String, _PendingDelete>.from(_pendingDeleteData);
    for (final entry in _pendingDeletes.values) entry.cancel();
    _pendingDeletes.clear();
    _pendingDeleteData.clear();
    
    for (final data in entries.values) {
      await removeMeal(data.date, data.instanceId);
    }
  }

  /// Get or create a plan for a specific date
  Future<MealPlan> getOrCreate(DateTime date) async {
    final dateStr = _formatDate(date);
    var plan = await _db.mealPlans.where().dateEqualTo(dateStr).findFirst();

    if (plan == null) {
      plan = MealPlan.create(date: dateStr, meals: []);
      await _db.writeTxn(() => _db.mealPlans.put(plan!));
    } else {
      // Lazy migration: Ensure IDs exist whenever we access a plan
      await _ensureInstanceIds(plan);
    }

    return plan;
  }

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

    final meal = PlannedMeal.create(
      recipeId: recipeId,
      recipeName: recipeName,
      course: course,
      servings: servings,
      notes: notes,
      cuisine: cuisine,
      recipeCategory: recipeCategory,
      instanceId: const Uuid().v4(), // Always generate ID
    );

    plan.meals = [...plan.meals, meal];
    await _db.writeTxn(() => _db.mealPlans.put(plan));
  }

  /// Remove a meal by unique Instance ID
  Future<void> removeMeal(DateTime date, String instanceId) async {
    final plan = await getOrCreate(date);
    
    final originalCount = plan.meals.length;
    final meals = List<PlannedMeal>.from(plan.meals);
    meals.removeWhere((m) => m.instanceId == instanceId);
    
    if (meals.length < originalCount) {
      plan.meals = meals;
      await _db.writeTxn(() => _db.mealPlans.put(plan));
    }
  }

  /// Move a meal from one date to another
  Future<void> moveMeal(
    DateTime fromDate,
    String instanceId, // Target by ID
    DateTime toDate,
    String newCourse,
  ) async {
    final fromPlan = await getOrCreate(fromDate);
    
    // Find the exact meal instance
    final mealIndex = fromPlan.meals.indexWhere((m) => m.instanceId == instanceId);
    if (mealIndex == -1) return;

    final meal = fromPlan.meals[mealIndex];
    
    // Remove from original date
    final fromMeals = List<PlannedMeal>.from(fromPlan.meals);
    fromMeals.removeAt(mealIndex);
    fromPlan.meals = fromMeals;

    // Add to new date (with same Instance ID to track identity, or new one? 
    // New ID is safer to prevent key collisions if dragging rapidly)
    final toPlan = await getOrCreate(toDate);
    final movedMeal = PlannedMeal.create(
      recipeId: meal.recipeId,
      recipeName: meal.recipeName,
      course: newCourse,
      servings: meal.servings,
      notes: meal.notes,
      cuisine: meal.cuisine,
      recipeCategory: meal.recipeCategory,
      instanceId: meal.instanceId, // Preserve ID if possible, or generate new
    );
    toPlan.meals = [...toPlan.meals, movedMeal];

    await _db.writeTxn(() async {
      await _db.mealPlans.put(fromPlan);
      await _db.mealPlans.put(toPlan);
    });
  }

  /// Get a week's worth of plans
  Future<WeeklyPlan> getWeek(DateTime weekStart) async {
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));
    final plans = <String, MealPlan>{};

    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateStr = _formatDate(date);
      final plan = await _db.mealPlans.where().dateEqualTo(dateStr).findFirst();
      if (plan != null) {
        // Ensure IDs exist
        await _ensureInstanceIds(plan);
        plans[dateStr] = plan;
      }
    }

    return WeeklyPlan(weekStart: monday, dailyPlans: plans);
  }

  Stream<List<MealPlan>> watchDateRange(DateTime start, DateTime end) {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    return _db.mealPlans.where().filter().dateGreaterThan(startStr).and().dateLessThan(endStr).watch(fireImmediately: true);
  }

  Future<void> clearDay(DateTime date) async {
    final dateStr = _formatDate(date);
    final plan = await _db.mealPlans.where().dateEqualTo(dateStr).findFirst();
    if (plan != null) {
      plan.meals = [];
      await _db.writeTxn(() => _db.mealPlans.put(plan));
    }
  }

  Future<void> copyDay(DateTime from, DateTime to) async {
    final fromPlan = await getOrCreate(from);
    final toPlan = await getOrCreate(to);

    final copiedMeals = fromPlan.meals.map((m) => PlannedMeal.create(
      recipeId: m.recipeId,
      recipeName: m.recipeName,
      course: m.course,
      servings: m.servings,
      notes: m.notes,
      cuisine: m.cuisine,
      recipeCategory: m.recipeCategory,
      instanceId: const Uuid().v4(), // Generate NEW IDs for copies
    )).toList();

    toPlan.meals = [...toPlan.meals, ...copiedMeals];
    await _db.writeTxn(() => _db.mealPlans.put(toPlan));
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Riverpod providers
final weeklyPlanProvider = FutureProvider.family<WeeklyPlan, DateTime>((ref, weekStart) async {
  final service = ref.watch(mealPlanServiceProvider);
  return service.getWeek(weekStart);
});

final selectedWeekProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
});