import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/widgets/memoix_drawer.dart';
import '../../recipes/models/category.dart';
import '../../recipes/models/cuisine.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen.dart';
import '../../recipes/widgets/cuisine_bottom_nav.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';

/// Selected cuisine filter provider
final selectedCuisineProvider = StateProvider<String?>((ref) => null);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _drawerSelectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);

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
          // Cuisine filter indicator
          if (selectedCuisine != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Text(Cuisine.byCode(selectedCuisine)?.flag ?? '🍽️'),
                label: Text(selectedCuisine),
                onPressed: () {
                  CuisineSelectorSheet.show(
                    context,
                    selectedCuisine: selectedCuisine,
                    onCuisineSelected: (cuisine) {
                      ref.read(selectedCuisineProvider.notifier).state = cuisine;
                    },
                  );
                },
              ),
            ),
        ],
      ),
      drawer: MemoixDrawer(
        selectedIndex: _drawerSelectedIndex,
        onItemSelected: (index) {
          setState(() => _drawerSelectedIndex = index);
        },
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categories) => _RecipeBrowser(
          categories: categories,
          selectedCuisine: selectedCuisine,
        ),
      ),
      bottomNavigationBar: CuisineBottomNav(
        selectedCuisine: selectedCuisine,
        onCuisineSelected: (cuisine) {
          ref.read(selectedCuisineProvider.notifier).state = cuisine;
        },
      ),
    );
  }
}

class _RecipeBrowser extends StatefulWidget {
  final List<Category> categories;
  final String? selectedCuisine;

  const _RecipeBrowser({
    required this.categories,
    this.selectedCuisine,
  });

  @override
  State<_RecipeBrowser> createState() => _RecipeBrowserState();
}

class _RecipeBrowserState extends State<_RecipeBrowser>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    // Dispose old controller first
    _tabController?.dispose();
    _tabController = null;
    
    // Only create new controller if we have categories
    if (widget.categories.isNotEmpty) {
      _tabController = TabController(
        length: widget.categories.length,
        vsync: this,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _RecipeBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize controller if category count changed
    if (oldWidget.categories.length != widget.categories.length) {
      // Use post-frame callback to avoid layout issues during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _initTabController();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Handle empty state gracefully
    if (widget.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No recipes yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync from Settings or add your own',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ],
        ),
      );
    }

    // Wait for tab controller to be ready
    if (_tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Course tabs (scrollable with mouse drag support)
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: widget.categories.map((category) {
                return Tab(
                  child: _CourseTab(category: category),
                );
              }).toList(),
            ),
          ),
        ),
        // Recipe list for selected course
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.categories.map((category) {
              return _CourseRecipeList(
                category: category,
                cuisineFilter: widget.selectedCuisine,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CourseTab extends StatelessWidget {
  final Category category;

  const _CourseTab({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _CourseRecipeList extends ConsumerWidget {
  final Category category;
  final String? cuisineFilter;

  const _CourseRecipeList({
    required this.category,
    this.cuisineFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RecipeListScreen(
      course: category.slug,
      cuisineFilter: cuisineFilter,
      showAddButton: true,
    );
  }
}
