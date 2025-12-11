import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/course_card.dart';
import '../../recipes/models/category.dart';
import '../../recipes/models/source_filter.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen_enhanced.dart';
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
                              body: RecipeListScreenEnhanced(
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
