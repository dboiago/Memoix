import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'database/database.dart';
import '../features/mealplan/models/meal_plan.dart';
import '../features/statistics/models/cooking_stats.dart';
import '../features/shopping/models/shopping_list.dart';

/// Shared providers for core services
final databaseProvider = Provider<Isar>((ref) => MemoixDatabase.instance);

final mealPlanServiceProvider = Provider<MealPlanService>((ref) {
  return MealPlanService(ref.watch(databaseProvider));
});

final cookingStatsServiceProvider = Provider<CookingStatsService>((ref) {
  return CookingStatsService(ref.watch(databaseProvider));
});

final shoppingListServiceProvider = Provider<ShoppingListService>((ref) {
  return ShoppingListService(ref.watch(databaseProvider));
});

// Theme mode provider (system / light / dark)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
