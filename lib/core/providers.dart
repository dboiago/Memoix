import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ADD THIS MISSING PROVIDER
final shoppingListsProvider = StreamProvider<List<ShoppingList>>((ref) {
  final service = ref.watch(shoppingListServiceProvider);
  return service.watchAll();
});

// Theme mode provider with persistence
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';
  
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadFromPrefs();
  }
  
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
    }
  }
  
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}