import 'package:flutter/cupertino.dart';
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
import '../../features/settings/screens/design_notes_screen.dart';
import '../../features/shopping/screens/shopping_list_screen.dart';
import '../../features/mealplan/screens/meal_plan_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/favourites/screens/favourites_screen.dart';
import '../../features/tools/measurement_converter.dart';
import '../../features/tools/kitchen_timer_screen.dart';
import '../../features/tools/recipe_comparison_screen.dart';
import '../../features/notes/screens/scratch_pad_screen.dart';
import '../../features/personal_storage/screens/personal_storage_screen.dart';
import '../../features/personal_storage/screens/shared_storage_screen.dart';
import '../../features/personal_storage/screens/share_storage_screen.dart';
import '../../features/personal_storage/models/storage_location.dart';

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
      CupertinoPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toRecipeList(BuildContext context, String course) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
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
      CupertinoPageRoute(
        builder: (_) => RecipeEditScreen(
          recipeId: recipeId,
          defaultCourse: course,
          importedRecipe: importedRecipe,
        ),
      ),
    );
  }

  static void toImport(BuildContext context, {String? course, bool redirectOnSave = false}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ImportScreen(
          defaultCourse: course,
          redirectOnSave: redirectOnSave,
        ),
      ),
    );
  }

  static void toQRScanner(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );
  }

  static void toOCRScanner(BuildContext context, {String? course, bool redirectOnSave = false}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => OCRScannerScreen(
          defaultCourse: course,
          redirectOnSave: redirectOnSave,
        ),
      ),
    );
  }

  static void toURLImport(BuildContext context, {String? course, bool redirectOnSave = false}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => URLImportScreen(
          defaultCourse: course,
          redirectOnSave: redirectOnSave,
        ),
      ),
    );
  }

  static void toShareRecipe(BuildContext context, {String? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ShareRecipeScreen(recipeId: recipeId),
      ),
    );
  }

  static void toSettings(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  static void toDesignNotes(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const DesignNotesScreen(),
      ),
    );
  }

  static void toShoppingLists(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const ShoppingListScreen(),
      ),
    );
  }

  static void toMealPlan(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const MealPlanScreen(),
      ),
    );
  }

  static void toStatistics(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const StatisticsScreen(),
      ),
    );
  }

  static void toFavourites(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const FavouritesScreen(),
      ),
    );
  }

  static void toUnitConverter(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const MeasurementConverterWidget(),
      ),
    );
  }

  static void toKitchenTimer(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const KitchenTimerWidget(),
      ),
    );
  }

  static void toScratchPad(BuildContext context, {String? draftUuid}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ScratchPadScreen(draftToEdit: draftUuid),
      ),
    );
  }

  static void toRecipeComparison(BuildContext context, {Recipe? prefilledRecipe}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => RecipeComparisonScreen(prefilledRecipe: prefilledRecipe),
      ),
    );
  }

  static void toPersonalStorage(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const PersonalStorageScreen(),
      ),
    );
  }

  static void toSharedStorage(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const SharedStorageScreen(),
      ),
    );
  }

  static void toShareRepository(BuildContext context, StorageLocation repository) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ShareStorageScreen(repository: repository),
      ),
    );
  }

  // ============ PIZZA ROUTES ============

  static void toPizzaList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const PizzaListScreen(),
      ),
    );
  }

  static void toPizzaDetail(BuildContext context, String pizzaId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => PizzaDetailScreen(pizzaId: pizzaId),
      ),
    );
  }

  static void toPizzaEdit(BuildContext context, {String? pizzaId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => PizzaEditScreen(pizzaId: pizzaId),
      ),
    );
  }

  // ============ SANDWICH ROUTES ============

  static void toSandwichList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const SandwichListScreen(),
      ),
    );
  }

  static void toSandwichDetail(BuildContext context, String sandwichId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => SandwichDetailScreen(sandwichId: sandwichId),
      ),
    );
  }

  static void toSandwichEdit(BuildContext context, {String? sandwichId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => SandwichEditScreen(sandwichId: sandwichId),
      ),
    );
  }

  // ============ SMOKING ROUTES ============

  static void toSmokingList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const SmokingListScreen(),
      ),
    );
  }

  static void toSmokingDetail(BuildContext context, String recipeId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => SmokingDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toSmokingEdit(BuildContext context, {String? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => SmokingEditScreen(recipeId: recipeId),
      ),
    );
  }

  // ============ MODERNIST ROUTES ============

  static void toModernistList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const ModernistListScreen(),
      ),
    );
  }

  static void toModernistDetail(BuildContext context, int recipeId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ModernistDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toModernistEdit(BuildContext context, {int? recipeId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => ModernistEditScreen(recipeId: recipeId),
      ),
    );
  }

  // ============ CHEESE ROUTES ============

  static void toCheeseList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const CheeseListScreen(),
      ),
    );
  }

  static void toCheeseDetail(BuildContext context, String entryId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => CheeseDetailScreen(entryId: entryId),
      ),
    );
  }

  static void toCheeseEdit(BuildContext context, {String? entryId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => CheeseEditScreen(entryId: entryId),
      ),
    );
  }

  // ============ CELLAR ROUTES ============

  static void toCellarList(BuildContext context) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => const CellarListScreen(),
      ),
    );
  }

  static void toCellarDetail(BuildContext context, String entryId) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => CellarDetailScreen(entryId: entryId),
      ),
    );
  }

  static void toCellarEdit(BuildContext context, {String? entryId}) {
    AppShellNavigator.navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => CellarEditScreen(entryId: entryId),
      ),
    );
  }
}
