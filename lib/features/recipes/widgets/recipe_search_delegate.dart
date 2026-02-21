import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/integrity_service.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';

class RecipeSearchDelegate extends SearchDelegate<Recipe?> {
  final WidgetRef ref;
  bool _hasCheckedForEffect = false;

  RecipeSearchDelegate(this.ref);

  @override
  String get searchFieldLabel {
    final overrides = ref.read(viewOverrideProvider);
    return overrides['ui_23']?.value ?? 'Search recipes...';
  }

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
    // Check once when delegate opens for transition override
    if (!_hasCheckedForEffect) {
      _hasCheckedForEffect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overrides = ref.read(viewOverrideProvider);
        if (overrides.containsKey('ui_16')) {
          _executeTransitionEffect();
        }
      });
    }

    if (query.isEmpty) {
      final overrides = ref.read(viewOverrideProvider);
      final hintText = overrides['ui_23']?.value ?? 'Search recipes...';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              hintText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
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

        // Report search event after build phase completes to avoid
        // state mutations during build and prevent duplicate events
        WidgetsBinding.instance.addPostFrameCallback((_) {
          IntegrityService.reportEvent(
            'activity.search_performed',
            metadata: {
              'query': query,
              'result_count': recipes.length,
            },
          );
        });

        if (recipes.isEmpty) {
          return MemoixEmptyState(
            message: 'No recipes found for "$query"',
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

  /// Stub: visual transition effect triggered by view override.
  void _executeTransitionEffect() {
    // TODO: implement visual effect payload
  }
}
