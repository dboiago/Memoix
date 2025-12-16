import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/widgets/recipe_card.dart';
import '../../recipes/models/recipe.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../cheese/widgets/cheese_card.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cellar/widgets/cellar_card.dart';
import '../../cellar/models/cellar_entry.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../pizzas/widgets/pizza_card.dart';
import '../../pizzas/models/pizza.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../sandwiches/widgets/sandwich_card.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../modernist/widgets/modernist_card.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../smoking/widgets/smoking_card.dart';
import '../../smoking/models/smoking_recipe.dart';

/// Enum for cuisine types in favourites
enum FavouriteCuisineType {
  all,
  recipes,
  cheese,
  cellar,
  pizzas,
  sandwiches,
  modernist,
  smoking,
}

/// Sort options for favourites
enum FavouriteSortOption {
  alphabetical,
  recentlyAdded,
  mostCooked,
  byCuisineType,
}

/// A wrapper class for any favorited item
class FavouriteItem {
  final Object item;
  final FavouriteCuisineType cuisineType;
  final String name;
  final DateTime? updatedAt;
  final int cookCount;

  FavouriteItem({
    required this.item,
    required this.cuisineType,
    required this.name,
    this.updatedAt,
    this.cookCount = 0,
  });
}

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  FavouriteCuisineType _selectedCuisineType = FavouriteCuisineType.all;
  FavouriteSortOption _sortOption = FavouriteSortOption.alphabetical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch all favorite providers
    final recipesAsync = ref.watch(favoriteRecipesProvider);
    final cheeseAsync = ref.watch(favoriteCheeseEntriesProvider);
    final cellarAsync = ref.watch(favoriteCellarEntriesProvider);
    final pizzasAsync = ref.watch(favoritePizzasProvider);
    final sandwichesAsync = ref.watch(favoriteSandwichesProvider);
    final modernistAsync = ref.watch(favoriteModernistRecipesProvider);
    final smokingAsync = ref.watch(favoriteSmokingRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
            tooltip: 'Filter by type',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(context),
            tooltip: 'Sort',
          ),
        ],
      ),
      body: _buildBody(
        theme,
        recipesAsync,
        cheeseAsync,
        cellarAsync,
        pizzasAsync,
        sandwichesAsync,
        modernistAsync,
        smokingAsync,
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    AsyncValue<List<Recipe>> recipesAsync,
    AsyncValue<List<CheeseEntry>> cheeseAsync,
    AsyncValue<List<CellarEntry>> cellarAsync,
    AsyncValue<List<Pizza>> pizzasAsync,
    AsyncValue<List<Sandwich>> sandwichesAsync,
    AsyncValue<List<ModernistRecipe>> modernistAsync,
    AsyncValue<List<SmokingRecipe>> smokingAsync,
  ) {
    // Check for loading state
    if (recipesAsync.isLoading ||
        cheeseAsync.isLoading ||
        cellarAsync.isLoading ||
        pizzasAsync.isLoading ||
        sandwichesAsync.isLoading ||
        modernistAsync.isLoading ||
        smokingAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check for errors
    if (recipesAsync.hasError) {
      return Center(child: Text('Error loading recipes: ${recipesAsync.error}'));
    }

    // Build aggregated list
    final items = <FavouriteItem>[];

    // Add recipes
    final recipes = recipesAsync.valueOrNull ?? [];
    for (final recipe in recipes) {
      items.add(FavouriteItem(
        item: recipe,
        cuisineType: FavouriteCuisineType.recipes,
        name: recipe.name,
        updatedAt: recipe.updatedAt,
        cookCount: recipe.cookCount,
      ));
    }

    // Add cheese entries
    final cheeses = cheeseAsync.valueOrNull ?? [];
    for (final cheese in cheeses) {
      items.add(FavouriteItem(
        item: cheese,
        cuisineType: FavouriteCuisineType.cheese,
        name: cheese.name,
        updatedAt: cheese.updatedAt,
      ));
    }

    // Add cellar entries
    final cellars = cellarAsync.valueOrNull ?? [];
    for (final cellar in cellars) {
      items.add(FavouriteItem(
        item: cellar,
        cuisineType: FavouriteCuisineType.cellar,
        name: cellar.name,
        updatedAt: cellar.updatedAt,
      ));
    }

    // Add pizzas
    final pizzas = pizzasAsync.valueOrNull ?? [];
    for (final pizza in pizzas) {
      items.add(FavouriteItem(
        item: pizza,
        cuisineType: FavouriteCuisineType.pizzas,
        name: pizza.name,
        updatedAt: pizza.updatedAt,
        cookCount: pizza.cookCount,
      ));
    }

    // Add sandwiches
    final sandwiches = sandwichesAsync.valueOrNull ?? [];
    for (final sandwich in sandwiches) {
      items.add(FavouriteItem(
        item: sandwich,
        cuisineType: FavouriteCuisineType.sandwiches,
        name: sandwich.name,
        updatedAt: sandwich.updatedAt,
        cookCount: sandwich.cookCount,
      ));
    }

    // Add modernist recipes
    final modernists = modernistAsync.valueOrNull ?? [];
    for (final modernist in modernists) {
      items.add(FavouriteItem(
        item: modernist,
        cuisineType: FavouriteCuisineType.modernist,
        name: modernist.name,
        updatedAt: modernist.updatedAt,
        cookCount: modernist.cookCount,
      ));
    }

    // Add smoking recipes
    final smokings = smokingAsync.valueOrNull ?? [];
    for (final smoking in smokings) {
      items.add(FavouriteItem(
        item: smoking,
        cuisineType: FavouriteCuisineType.smoking,
        name: smoking.name,
        updatedAt: smoking.updatedAt,
        cookCount: smoking.cookCount,
      ));
    }

    // Filter by cuisine type
    final filteredItems = _selectedCuisineType == FavouriteCuisineType.all
        ? items
        : items.where((i) => i.cuisineType == _selectedCuisineType).toList();

    // Sort items
    _sortItems(filteredItems);

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No favourites yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on items you love\nto add them here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final showHeader = _sortOption == FavouriteSortOption.byCuisineType &&
            (index == 0 || filteredItems[index - 1].cuisineType != item.cuisineType);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              if (index > 0) const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  _getCuisineTypeLabel(item.cuisineType),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildCard(item),
            ),
          ],
        );
      },
    );
  }

  String _getCuisineTypeLabel(FavouriteCuisineType type) {
    switch (type) {
      case FavouriteCuisineType.recipes:
        return 'Recipes';
      case FavouriteCuisineType.cheese:
        return 'Cheese';
      case FavouriteCuisineType.cellar:
        return 'Cellar';
      case FavouriteCuisineType.pizzas:
        return 'Pizzas';
      case FavouriteCuisineType.sandwiches:
        return 'Sandwiches';
      case FavouriteCuisineType.modernist:
        return 'Modernist';
      case FavouriteCuisineType.smoking:
        return 'Smoking';
      case FavouriteCuisineType.all:
        return 'All';
    }
  }

  Widget _buildCard(FavouriteItem item) {
    switch (item.cuisineType) {
      case FavouriteCuisineType.recipes:
        final recipe = item.item as Recipe;
        return RecipeCard(
          recipe: recipe,
          onTap: () => AppRoutes.toRecipeDetail(context, recipe.uuid),
        );
      case FavouriteCuisineType.cheese:
        final cheese = item.item as CheeseEntry;
        return CheeseCard(
          entry: cheese,
          onTap: () => AppRoutes.toCheeseDetail(context, cheese.uuid),
        );
      case FavouriteCuisineType.cellar:
        final cellar = item.item as CellarEntry;
        return CellarCard(
          entry: cellar,
          onTap: () => AppRoutes.toCellarDetail(context, cellar.uuid),
        );
      case FavouriteCuisineType.pizzas:
        final pizza = item.item as Pizza;
        return PizzaCard(
          pizza: pizza,
          onTap: () => AppRoutes.toPizzaDetail(context, pizza.uuid),
        );
      case FavouriteCuisineType.sandwiches:
        final sandwich = item.item as Sandwich;
        return SandwichCard(
          sandwich: sandwich,
          onTap: () => AppRoutes.toSandwichDetail(context, sandwich.uuid),
        );
      case FavouriteCuisineType.modernist:
        final modernist = item.item as ModernistRecipe;
        return ModernistCard(
          recipe: modernist,
          onTap: () => AppRoutes.toModernistDetail(context, modernist.id),
        );
      case FavouriteCuisineType.smoking:
        final smoking = item.item as SmokingRecipe;
        return SmokingCard(
          recipe: smoking,
          onTap: () => AppRoutes.toSmokingDetail(context, smoking.uuid),
        );
      case FavouriteCuisineType.all:
        // This should never happen since we filter first
        return const SizedBox.shrink();
    }
  }

  void _sortItems(List<FavouriteItem> items) {
    switch (_sortOption) {
      case FavouriteSortOption.alphabetical:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FavouriteSortOption.recentlyAdded:
        items.sort((a, b) {
          final aDate = a.updatedAt ?? DateTime(1970);
          final bDate = b.updatedAt ?? DateTime(1970);
          return bDate.compareTo(aDate); // Newest first
        });
        break;
      case FavouriteSortOption.mostCooked:
        items.sort((a, b) => b.cookCount.compareTo(a.cookCount));
        break;
      case FavouriteSortOption.byCuisineType:
        items.sort((a, b) {
          final typeCompare = a.cuisineType.index.compareTo(b.cuisineType.index);
          if (typeCompare != 0) return typeCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
  }

  void _showFilterOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('All'),
            trailing: _selectedCuisineType == FavouriteCuisineType.all
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.all);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Recipes'),
            trailing: _selectedCuisineType == FavouriteCuisineType.recipes
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.recipes);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Cheese'),
            trailing: _selectedCuisineType == FavouriteCuisineType.cheese
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.cheese);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Cellar'),
            trailing: _selectedCuisineType == FavouriteCuisineType.cellar
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.cellar);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Pizzas'),
            trailing: _selectedCuisineType == FavouriteCuisineType.pizzas
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.pizzas);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Sandwiches'),
            trailing: _selectedCuisineType == FavouriteCuisineType.sandwiches
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.sandwiches);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Modernist'),
            trailing: _selectedCuisineType == FavouriteCuisineType.modernist
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.modernist);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Smoking'),
            trailing: _selectedCuisineType == FavouriteCuisineType.smoking
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _selectedCuisineType = FavouriteCuisineType.smoking);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Alphabetical'),
            trailing: _sortOption == FavouriteSortOption.alphabetical
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _sortOption = FavouriteSortOption.alphabetical);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Recently Added'),
            trailing: _sortOption == FavouriteSortOption.recentlyAdded
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _sortOption = FavouriteSortOption.recentlyAdded);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Most Cooked'),
            trailing: _sortOption == FavouriteSortOption.mostCooked
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _sortOption = FavouriteSortOption.mostCooked);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('By Cuisine Type'),
            trailing: _sortOption == FavouriteSortOption.byCuisineType
                ? Icon(Icons.check, color: theme.colorScheme.secondary)
                : null,
            onTap: () {
              setState(() => _sortOption = FavouriteSortOption.byCuisineType);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
