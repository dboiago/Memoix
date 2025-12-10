import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../recipes/models/category.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Memoix',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: RecipeSearchDelegate(ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => AppRoutes.toImport(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'mealplan',
                child: ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Meal Plan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'shopping',
                child: ListTile(
                  leading: Icon(Icons.shopping_cart),
                  title: Text('Shopping Lists'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'converter',
                child: ListTile(
                  leading: Icon(Icons.straighten),
                  title: Text('Unit Converter'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() => _selectedIndex = index),
          tabs: const [
            Tab(text: 'Memoix', icon: Icon(Icons.restaurant_menu)),
            Tab(text: 'My Recipes', icon: Icon(Icons.person)),
            Tab(text: 'Favorites', icon: Icon(Icons.favorite)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MemoixCollectionTab(),
          PersonalRecipesTab(),
          FavoritesTab(),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'mealplan':
        AppRoutes.toMealPlan(context);
        break;
      case 'shopping':
        AppRoutes.toShoppingLists(context);
        break;
      case 'converter':
        AppRoutes.toUnitConverter(context);
        break;
      case 'settings':
        AppRoutes.toSettings(context);
        break;
    }
  }
}

/// Tab showing the official Memoix collection (from GitHub)
class MemoixCollectionTab extends ConsumerWidget {
  const MemoixCollectionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (categories) => CategoryRecipeView(
        categories: categories,
        sourceFilter: RecipeSourceFilter.memoix,
      ),
    );
  }
}

/// Tab showing user's personal recipes
class PersonalRecipesTab extends ConsumerWidget {
  const PersonalRecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (categories) => CategoryRecipeView(
        categories: categories,
        sourceFilter: RecipeSourceFilter.personal,
        emptyMessage: 'No personal recipes yet.\nTap + to add your first recipe!',
      ),
    );
  }
}

/// Tab showing favorite recipes
class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteRecipesProvider);

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (recipes) {
        if (recipes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No favorites yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the heart on a recipe to add it here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return RecipeListView(recipes: recipes);
      },
    );
  }
}

enum RecipeSourceFilter { memoix, personal, all }

/// View showing recipes organized by categories (like spreadsheet tabs)
class CategoryRecipeView extends StatefulWidget {
  final List<Category> categories;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;

  const CategoryRecipeView({
    super.key,
    required this.categories,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
  });

  @override
  State<CategoryRecipeView> createState() => _CategoryRecipeViewState();
}

class _CategoryRecipeViewState extends State<CategoryRecipeView> with SingleTickerProviderStateMixin {
  late TabController _categoryTabController;

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: widget.categories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return Column(
      children: [
        // Category tabs (scrollable, like spreadsheet tabs at bottom)
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _categoryTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: widget.categories.map((category) {
              return Tab(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(category.name),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Recipe list for selected category
        Expanded(
          child: TabBarView(
            controller: _categoryTabController,
            children: widget.categories.map((category) {
              return RecipeListScreen(
                course: category.slug,
                sourceFilter: widget.sourceFilter,
                emptyMessage: widget.emptyMessage,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
