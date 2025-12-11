import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/course_card.dart';
import '../../recipes/models/category.dart';
import '../../recipes/models/source_filter.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Recipe Book',
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
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categories) => _CourseGridView(categories: categories),
      ),
    );
  }
}

/// View showing courses as a grid of cards matching Figma design
class _CourseGridView extends ConsumerWidget {
  final List<Category> categories;

  const _CourseGridView({required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('No categories found'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: 2 cols on mobile, 3 on tablet, 4 on desktop
        int crossAxisCount = 2;
        if (constraints.maxWidth >= 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 3;
        }

        return CustomScrollView(
          slivers: [
            // Search bar at top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  hintText: 'Search recipes...',
                  leading: const Icon(Icons.search),
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: RecipeSearchDelegate(ref),
                    );
                  },
                ),
              ),
            ),
            
            // Course cards grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = categories[index];
                    
                    // Get recipe count for this category
                    final recipesAsync = ref.watch(
                      recipesByCourseProvider(category.slug),
                    );
                    
                    final recipeCount = recipesAsync.maybeWhen(
                      data: (recipes) => recipes.length,
                      orElse: () => 0,
                    );

                    return CourseCard(
                      category: category,
                      recipeCount: recipeCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(category.name),
                              ),
                              body: RecipeListScreen(
                                course: category.slug,
                                sourceFilter: RecipeSourceFilter.all,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: categories.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// View showing recipes organized by categories (like spreadsheet tabs)
/// DEPRECATED: Keeping for reference, but now using CourseGridView
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
