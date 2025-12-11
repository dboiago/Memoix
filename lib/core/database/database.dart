import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/models/category.dart';
import '../../features/shopping/models/shopping_list.dart';
import '../../features/mealplan/models/meal_plan.dart';
import '../../features/statistics/models/cooking_stats.dart';

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
        CategorySchema,
        ShoppingListSchema,
        MealPlanSchema,
        CookingLogSchema,
      ],
      directory: dir.path,
      name: 'memoix',
    );

    // Seed default categories if empty
    await _seedDefaultCategories();
  }

  /// Seed default categories on first run
  static Future<void> _seedDefaultCategories() async {
    final db = instance;
    final count = await db.categorys.count();
    
    if (count == 0) {
      await db.writeTxn(() async {
        await db.categorys.putAll(Category.defaults);
      });
    }
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
    await _seedDefaultCategories();
  }
}
