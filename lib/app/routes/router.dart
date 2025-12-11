import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/recipes/screens/recipe_edit_screen.dart';
import '../../features/recipes/screens/recipe_list_screen.dart';
import '../../features/recipes/models/source_filter.dart';
import '../../features/import/screens/import_screen.dart';
import '../../features/import/screens/qr_scanner_screen.dart';
import '../../features/import/screens/ocr_scanner_screen.dart';
import '../../features/import/screens/url_import_screen.dart';
import '../../features/import/screens/share_recipe_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shopping/screens/shopping_list_screen.dart';
import '../../features/mealplan/screens/meal_plan_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/favourites/screens/favourites_screen.dart';
import '../../features/tools/measurement_converter.dart';
import '../../features/tools/kitchen_timer.dart';
import '../../features/notes/screens/scratch_pad_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell();
  }
}

/// Navigation helper for pushing routes
class AppRoutes {
  AppRoutes._();

  static void toRecipeDetail(BuildContext context, String recipeId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toRecipeList(BuildContext context, String course) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => RecipeListScreen(
          course: course,
          sourceFilter: RecipeSourceFilter.all,
          showAddButton: true,
        ),
      ),
    );
  }

  static void toRecipeEdit(BuildContext context, {String? recipeId, String? course}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(recipeId: recipeId, defaultCourse: course),
      ),
    );
  }

  static void toImport(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const ImportScreen(),
      ),
    );
  }

  static void toQRScanner(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );
  }

  static void toOCRScanner(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const OCRScannerScreen(),
      ),
    );
  }

  static void toURLImport(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const URLImportScreen(),
      ),
    );
  }

  static void toShareRecipe(BuildContext context, {String? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ShareRecipeScreen(recipeId: recipeId),
      ),
    );
  }

  static void toSettings(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  static void toShoppingLists(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const ShoppingListScreen(),
      ),
    );
  }

  static void toMealPlan(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const MealPlanScreen(),
      ),
    );
  }

  static void toStatistics(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const StatisticsScreen(),
      ),
    );
  }

  static void toFavourites(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const FavouritesScreen(),
      ),
    );
  }

  static void toUnitConverter(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const MeasurementConverterWidget(),
      ),
    );
  }

  static void toKitchenTimer(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const KitchenTimerWidget(),
      ),
    );
  }

  static void toScratchPad(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const ScratchPadScreen(),
      ),
    );
  }
}
