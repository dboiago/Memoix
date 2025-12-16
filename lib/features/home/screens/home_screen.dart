import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../shared/widgets/course_card.dart';
import '../../recipes/models/category.dart';
import '../../recipes/models/source_filter.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../modernist/repository/modernist_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (categories) => _CourseGridView(categories: categories),
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
        // Calculate target columns based on width, then derive extent
        // This ensures cards grow to fill available space
        final width = constraints.maxWidth - 32; // account for padding
        int targetColumns;
        if (width >= 1400) {
          targetColumns = 9;
        } else if (width >= 1100) {
          targetColumns = 7;
        } else if (width >= 800) {
          targetColumns = 5;
        } else if (width >= 500) {
          targetColumns = 4;
        } else {
          targetColumns = 3;
        }
        // Calculate extent so cards fill the row (minus spacing)
        final spacing = 12.0 * (targetColumns - 1);
        final maxExtent = (width - spacing) / targetColumns;

        return CustomScrollView(
          slivers: [
            // Search bar at top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return TextField(
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      readOnly: true,
                      onTap: () {
                        showSearch(
                          context: context,
                          delegate: RecipeSearchDelegate(ref),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Course cards grid - uses maxCrossAxisExtent for auto column count
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3, // slightly wider than tall
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = categories[index];
                    
                    // Special handling for pizzas, sandwiches, and smoking - use their own counts
                    final bool isPizza = category.slug == 'pizzas';
                    final bool isSandwich = category.slug == 'sandwiches';
                    final bool isSmoking = category.slug == 'smoking';
                    final bool isModernist = category.slug == 'modernist';
                    
                    // Get count for this category
                    final int itemCount;
                    if (isPizza) {
                      final pizzasAsync = ref.watch(pizzaCountProvider);
                      itemCount = pizzasAsync.maybeWhen(
                        data: (count) => count,
                        orElse: () => 0,
                      );
                    } else if (isSandwich) {
                      final sandwichesAsync = ref.watch(sandwichCountProvider);
                      itemCount = sandwichesAsync.maybeWhen(
                        data: (count) => count,
                        orElse: () => 0,
                      );
                    } else if (isSmoking) {
                      final smokingAsync = ref.watch(smokingCountProvider);
                      itemCount = smokingAsync.maybeWhen(
                        data: (count) => count,
                        orElse: () => 0,
                      );
                    } else if (isModernist) {
                      final modernistAsync = ref.watch(modernistCountProvider);
                      itemCount = modernistAsync.maybeWhen(
                        data: (count) => count,
                        orElse: () => 0,
                      );
                    } else {
                      final recipesAsync = ref.watch(
                        recipesByCourseProvider(category.slug),
                      );
                      itemCount = recipesAsync.maybeWhen(
                        data: (recipes) => recipes.length,
                        orElse: () => 0,
                      );
                    }

                    return CourseCard(
                      category: category,
                      recipeCount: itemCount,
                      onTap: () {
                        // Special category routing
                        if (category.slug == 'scratch') {
                          AppRoutes.toScratchPad(context);
                        } else if (category.slug == 'pizzas') {
                          AppRoutes.toPizzaList(context);
                        } else if (category.slug == 'sandwiches') {
                          AppRoutes.toSandwichList(context);
                        } else if (category.slug == 'smoking') {
                          AppRoutes.toSmokingList(context);
                        } else if (category.slug == 'modernist') {
                          AppRoutes.toModernistList(context);
                        } else {
                          AppRoutes.toRecipeList(context, category.slug);
                        }
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
