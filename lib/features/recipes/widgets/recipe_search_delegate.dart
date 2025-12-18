import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';

class RecipeSearchDelegate extends SearchDelegate<Recipe?> {
  final WidgetRef ref;

  RecipeSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search recipes by name,\ncuisine, or ingredients',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final searchFuture = ref.read(recipeSearchProvider(query).future);

    return FutureBuilder<List<Recipe>>(
      future: searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recipes = snapshot.data ?? [];

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No recipes found for "$query"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.restaurant),
              ),
              title: Text(recipe.name),
              subtitle: Text(
                [recipe.cuisine, recipe.course].whereType<String>().join(' • '),
              ),
              trailing: recipe.isFavorite
                  ? Icon(Icons.favorite, color: MemoixColors.favorite, size: 20)
                  : null,
              onTap: () async {
                close(context, recipe);
                // Verify recipe still exists before navigating
                final exists = await ref.read(recipeRepositoryProvider).getRecipeByUuid(recipe.uuid);
                if (exists != null) {
                  AppRoutes.toRecipeDetail(context, recipe.uuid);
                }
              },
            );
          },
        );
      },
    );
  }
}
