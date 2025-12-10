import 'package:flutter/material.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/import/screens/import_screen.dart';
import '../../features/import/screens/qr_scanner_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shopping/screens/shopping_list_screen.dart';
import '../../features/mealplan/screens/meal_plan_screen.dart';
import '../../features/tools/measurement_converter.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

/// Navigation helper for pushing routes
class AppRoutes {
  AppRoutes._();

  static void toRecipeDetail(BuildContext context, String recipeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
  }

  static void toImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ImportScreen(),
      ),
    );
  }

  static void toQRScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(),
      ),
    );
  }

  static void toSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  static void toShoppingLists(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShoppingListScreen(),
      ),
    );
  }

  static void toMealPlan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MealPlanScreen(),
      ),
    );
  }

  static void toUnitConverter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MeasurementConverterWidget(),
      ),
    );
  }
}
