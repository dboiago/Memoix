import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

part 'meal_plan.g.dart';

/// Represents a single planned meal
@embedded
class PlannedMeal {
  String? recipeId;
  String? recipeName;
  String? course; // breakfast, lunch, dinner, snack
  String? notes;
  int? servings;
  String? cuisine; // e.g., "Korean", "Italian"
  String? recipeCategory; // e.g., "mains", "soup"

  PlannedMeal();

  PlannedMeal.create({
    required this.recipeId,
    required this.recipeName,
    this.course,
    this.notes,
    this.servings,
    this.cuisine,
    this.recipeCategory,
  });
}

/// A meal plan for a specific date
@collection
class MealPlan {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String date; // Format: 'yyyy-MM-dd'

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
  final Map<String, MealPlan> dailyPlans; // date string -> plan

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
    // Removed emojis for cleaner design
    return '';
  }
}

/// Service for managing meal plans
class MealPlanService {
  final Isar _db;

  MealPlanService(this._db);

  /// Get or create a plan for a specific date
  Future<MealPlan> getOrCreate(DateTime date) async {
    final dateStr = _formatDate(date);
    var plan = await _db.mealPlans.where().dateEqualTo(dateStr).findFirst();

    if (plan == null) {
      plan = MealPlan.create(date: dateStr, meals: []);
      await _db.writeTxn(() => _db.mealPlans.put(plan!));
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
    );

    plan.meals = [...plan.meals, meal];
    await _db.writeTxn(() => _db.mealPlans.put(plan));
  }

  /// Remove a meal from a date
  Future<void> removeMeal(DateTime date, int mealIndex) async {
    final plan = await getOrCreate(date);
    if (mealIndex >= 0 && mealIndex < plan.meals.length) {
      final meals = List<PlannedMeal>.from(plan.meals);
      meals.removeAt(mealIndex);
      plan.meals = meals;
      await _db.writeTxn(() => _db.mealPlans.put(plan));
    }
  }

  /// Move a meal from one date to another
  Future<void> moveMeal(
    DateTime fromDate,
    int mealIndex,
    DateTime toDate,
    String newCourse,
  ) async {
    final fromPlan = await getOrCreate(fromDate);
    if (mealIndex < 0 || mealIndex >= fromPlan.meals.length) return;

    final meal = fromPlan.meals[mealIndex];
    
    // Remove from original date
    final fromMeals = List<PlannedMeal>.from(fromPlan.meals);
    fromMeals.removeAt(mealIndex);
    fromPlan.meals = fromMeals;

    // Add to new date
    final toPlan = await getOrCreate(toDate);
    final movedMeal = PlannedMeal.create(
      recipeId: meal.recipeId,
      recipeName: meal.recipeName,
      course: newCourse,
      servings: meal.servings,
      notes: meal.notes,
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
        plans[dateStr] = plan;
      }
    }

    return WeeklyPlan(weekStart: monday, dailyPlans: plans);
  }

  /// Watch plans for a date range
  Stream<List<MealPlan>> watchDateRange(DateTime start, DateTime end) {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    
    return _db.mealPlans
        .where()
        .filter()
        .dateGreaterThan(startStr)
        .and()
        .dateLessThan(endStr)
        .watch(fireImmediately: true);
  }

  /// Clear all meals for a date
  Future<void> clearDay(DateTime date) async {
    final dateStr = _formatDate(date);
    final plan = await _db.mealPlans.where().dateEqualTo(dateStr).findFirst();
    if (plan != null) {
      plan.meals = [];
      await _db.writeTxn(() => _db.mealPlans.put(plan));
    }
  }

  /// Copy a day's meals to another day
  Future<void> copyDay(DateTime from, DateTime to) async {
    final fromPlan = await getOrCreate(from);
    final toPlan = await getOrCreate(to);

    final copiedMeals = fromPlan.meals.map((m) => PlannedMeal.create(
      recipeId: m.recipeId,
      recipeName: m.recipeName,
      course: m.course,
      servings: m.servings,
      notes: m.notes,
    ),).toList();

    toPlan.meals = [...toPlan.meals, ...copiedMeals];
    await _db.writeTxn(() => _db.mealPlans.put(toPlan));
  }

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
