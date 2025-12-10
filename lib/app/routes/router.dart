import 'package:flutter/material.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/import/screens/import_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

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

  static void toSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}
