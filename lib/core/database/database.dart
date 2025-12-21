import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/models/course.dart';
import '../../features/pizzas/models/pizza.dart';
import '../../features/sandwiches/models/sandwich.dart';
import '../../features/smoking/models/smoking_recipe.dart';
import '../../features/modernist/models/modernist_recipe.dart';
import '../../features/shopping/models/shopping_list.dart';
import '../../features/mealplan/models/meal_plan.dart';
import '../../features/statistics/models/cooking_stats.dart';
import '../../features/notes/models/scratch_pad.dart';
import '../../features/cheese/models/cheese_entry.dart';
import '../../features/cellar/models/cellar_entry.dart';

/// Singleton database manager for Memoix
class MemoixDatabase {
  static Isar? _instance;

  MemoixDatabase._();

  /// Get the Isar database instance
  static Isar get instance {
    if (_instance == null) {
      throw Exception('Database not initialized. Call MemoixDatabase.initialize() first.');
    }
    return _instance!;
  }

  /// Initialize the database
  static Future<void> initialize() async {
    if (_instance != null) return;

    final dir = await getApplicationDocumentsDirectory();
    
    _instance = await Isar.open(
      [
        RecipeSchema,
        CourseSchema,
        PizzaSchema,
        SandwichSchema,
        SmokingRecipeSchema,
        ModernistRecipeSchema,
        ShoppingListSchema,
        MealPlanSchema,
        CookingLogSchema,
        ScratchPadSchema,
        RecipeDraftSchema,
        CheeseEntrySchema,
        CellarEntrySchema,
      ],
      directory: dir.path,
      name: 'memoix',
    );

    // Seed default courses if empty
    await _seedDefaultCourses();
  }

  /// Seed default courses on first run
  static Future<void> _seedDefaultCourses() async {
    final db = instance;
    final count = await db.courses.count();
    
    if (count == 0) {
      await db.writeTxn(() async {
        await db.courses.putAll(Course.defaults);
      });
    }
  }

  /// Refresh courses with latest defaults (updates order, names, etc.)
  /// Call this on app startup to apply course changes
  static Future<void> refreshCourses() async {
    final db = instance;
    await db.writeTxn(() async {
      // Clear existing courses and replace with fresh defaults
      await db.courses.clear();
      await db.courses.putAll(Course.defaults);
    });
  }

  /// Close the database (call on app dispose)
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Clear all data (for testing/reset)
  static Future<void> clearAll() async {
    final db = instance;
    await db.writeTxn(() async {
      await db.clear();
    });
    await _seedDefaultCourses();
  }
}
