// This file is deprecated and can be deleted.
// The app now uses home_screen_new.dart instead.
// Please delete this file manually.

// Old content removed to prevent confusion.

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
        data: (categories) => CourseGridView(
          categories: categories,
          sourceFilter: RecipeSourceFilter.all,
        ),
      ),
    );
  }
}



// `RecipeSourceFilter` moved to `features/recipes/models/source_filter.dart`

/// View showing courses as a grid of cards matching Figma design
class CourseGridView extends ConsumerWidget {
  final List<Category> categories;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;

  const CourseGridView({
    super.key,
    required this.categories,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return Center(
        child: Text(emptyMessage ?? 'No categories found'),
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
                    
                    // Get recipe count for this category with source filter
                    final recipesAsync = ref.watch(
                      recipesByCourseProvider(
                        (course: category.slug, sourceFilter: sourceFilter),
                      ),
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
                                sourceFilter: sourceFilter,
                                emptyMessage: emptyMessage,
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
