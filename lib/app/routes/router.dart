import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/recipes/screens/recipe_edit_screen.dart';
import '../../features/recipes/screens/recipe_list_screen.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/models/source_filter.dart';
import '../../features/pizzas/screens/pizza_list_screen.dart';
import '../../features/pizzas/screens/pizza_detail_screen.dart';
import '../../features/pizzas/screens/pizza_edit_screen.dart';
import '../../features/sandwiches/screens/sandwich_list_screen.dart';
import '../../features/sandwiches/screens/sandwich_detail_screen.dart';
import '../../features/sandwiches/screens/sandwich_edit_screen.dart';
import '../../features/smoking/screens/smoking_list_screen.dart';
import '../../features/smoking/screens/smoking_detail_screen.dart';
import '../../features/smoking/screens/smoking_edit_screen.dart';
import '../../features/modernist/screens/modernist_list_screen.dart';
import '../../features/modernist/screens/modernist_detail_screen.dart';
import '../../features/modernist/screens/modernist_edit_screen.dart';
import '../../features/cheese/screens/cheese_list_screen.dart';
import '../../features/cheese/screens/cheese_detail_screen.dart';
import '../../features/cheese/screens/cheese_edit_screen.dart';
import '../../features/cellar/screens/cellar_list_screen.dart';
import '../../features/cellar/screens/cellar_detail_screen.dart';
import '../../features/cellar/screens/cellar_edit_screen.dart';
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
import '../../features/tools/kitchen_timer_screen.dart';
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

  static void toRecipeEdit(BuildContext context, {String? recipeId, String? course, Recipe? importedRecipe}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(
          recipeId: recipeId,
          defaultCourse: course,
          importedRecipe: importedRecipe,
        ),
      ),
    );
  }

  static void toImport(BuildContext context, {String? course}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ImportScreen(defaultCourse: course),
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

  static void toOCRScanner(BuildContext context, {String? course}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => OCRScannerScreen(defaultCourse: course),
      ),
    );
  }

  static void toURLImport(BuildContext context, {String? course}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => URLImportScreen(defaultCourse: course),
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

  // ============ PIZZA ROUTES ============

  static void toPizzaList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const PizzaListScreen(),
      ),
    );
  }

  static void toPizzaDetail(BuildContext context, String pizzaId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PizzaDetailScreen(pizzaId: pizzaId),
      ),
    );
  }

  static void toPizzaEdit(BuildContext context, {String? pizzaId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PizzaEditScreen(pizzaId: pizzaId),
      ),
    );
  }

  // ============ SANDWICH ROUTES ============

  static void toSandwichList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const SandwichListScreen(),
      ),
    );
  }

  static void toSandwichDetail(BuildContext context, String sandwichId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SandwichDetailScreen(sandwichId: sandwichId),
      ),
    );
  }

  static void toSandwichEdit(BuildContext context, {String? sandwichId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SandwichEditScreen(sandwichId: sandwichId),
      ),
    );
  }

  // ============ SMOKING ROUTES ============

  static void toSmokingList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const SmokingListScreen(),
      ),
    );
  }

  static void toSmokingDetail(BuildContext context, String recipeId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SmokingDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toSmokingEdit(BuildContext context, {String? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SmokingEditScreen(recipeId: recipeId),
      ),
    );
  }

  // ============ MODERNIST ROUTES ============

  static void toModernistList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const ModernistListScreen(),
      ),
    );
  }

  static void toModernistDetail(BuildContext context, int recipeId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ModernistDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toModernistEdit(BuildContext context, {int? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ModernistEditScreen(recipeId: recipeId),
      ),
    );
  }

  // ============ CHEESE ROUTES ============

  static void toCheeseList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const CheeseListScreen(),
      ),
    );
  }

  static void toCheeseDetail(BuildContext context, String entryId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => CheeseDetailScreen(entryId: entryId),
      ),
    );
  }

  static void toCheeseEdit(BuildContext context, {String? entryId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => CheeseEditScreen(entryId: entryId),
      ),
    );
  }

  // ============ CELLAR ROUTES ============

  static void toCellarList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const CellarListScreen(),
      ),
    );
  }

  static void toCellarDetail(BuildContext context, String entryId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => CellarDetailScreen(entryId: entryId),
      ),
    );
  }

  static void toCellarEdit(BuildContext context, {String? entryId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => CellarEditScreen(entryId: entryId),
      ),
    );
  }
}
