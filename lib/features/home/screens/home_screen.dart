import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/services/integrity_service.dart';
import '../../../shared/widgets/course_card.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/source_filter.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_list_screen.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cellar/models/cellar_entry.dart';
import '../../notes/repository/scratch_pad_repository.dart';
import '../../settings/screens/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (courses) => _CourseGridView(courses: courses),
    );
  }
}

/// View showing courses as a grid of cards
class _CourseGridView extends ConsumerStatefulWidget {
  final List<Course> courses;

  const _CourseGridView({required this.courses});

  @override
  ConsumerState<_CourseGridView> createState() => _CourseGridViewState();
}

class _CourseGridViewState extends ConsumerState<_CourseGridView> {
  String? _lastConsumedHintValue;
  dynamic _lastConsumedIconValue;

  @override
  Widget build(BuildContext context) {
    final courses = widget.courses;
    if (courses.isEmpty) {
      return const Center(
        child: Text('No courses found'),
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
        } else if (width >= 600) {
          targetColumns = 4;
        } else if (width >= 400) {
          targetColumns = 3;
        } else {
          targetColumns = 2; // Phone portrait - 2 columns for legibility
        }
        // Calculate extent so cards fill the row (minus spacing)
        final spacing = 6.0 * (targetColumns - 1);
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
                    final overrides = ref.watch(viewOverrideProvider);
                    final hintOverride = overrides['ui_23'];
                    String searchHint = 'Search recipes...';
                    if (hintOverride?.value is Map) {
                      searchHint = (hintOverride!.value as Map)['hint']?.toString() ?? 'Search recipes...';
                    } else if (hintOverride?.value != null) {
                      searchHint = hintOverride!.value.toString();
                    }

                    final searchIcon = overrides.containsKey('ui_41')
                        ? _resolveIcon(overrides['ui_41']!.value)
                        : Icons.search;

                    if (hintOverride != null && hintOverride.value != _lastConsumedHintValue) {
                      _lastConsumedHintValue = hintOverride.value;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(viewOverrideProvider.notifier).consumeUse('ui_23');
                        }
                      });
                    }

                    final iconOverride = overrides['ui_41'];
                    if (iconOverride != null && iconOverride.value != _lastConsumedIconValue) {
                      _lastConsumedIconValue = iconOverride.value;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(viewOverrideProvider.notifier).consumeUse('ui_41');
                        }
                      });
                    }

                    return TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixIcon: Icon(searchIcon, color: theme.colorScheme.onSurfaceVariant),
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
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3, // slightly wider than tall
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final course = courses[index];
                    final hideMemoix = ref.watch(hideMemoixRecipesProvider);
                    
                    // Special handling for pizzas, sandwiches, smoking, cheese, cellar - use their own counts
                    final bool isPizza = course.slug == 'pizzas';
                    final bool isSandwich = course.slug == 'sandwiches';
                    final bool isSmoking = course.slug == 'smoking';
                    final bool isModernist = course.slug == 'modernist';
                    final bool isCheese = course.slug == 'cheese';
                    final bool isCellar = course.slug == 'cellar';
                    final bool isScratch = course.slug == 'scratch';
                    
                    // Get count for this category (respecting hideMemoix setting)
                    final int itemCount;
                    if (isScratch) {
                      // For Scratch Pad, show draft count
                      final draftsAsync = ref.watch(recipeDraftsProvider);
                      itemCount = draftsAsync.maybeWhen(
                        data: (drafts) => drafts.length,
                        orElse: () => 0,
                      );
                    } else if (isPizza) {
                      final pizzasAsync = ref.watch(allPizzasProvider);
                      itemCount = pizzasAsync.maybeWhen(
                        data: (pizzas) => hideMemoix
                            ? pizzas.where((p) => p.source != PizzaSource.memoix).length
                            : pizzas.length,
                        orElse: () => 0,
                      );
                    } else if (isSandwich) {
                      final sandwichesAsync = ref.watch(allSandwichesProvider);
                      itemCount = sandwichesAsync.maybeWhen(
                        data: (sandwiches) => hideMemoix
                            ? sandwiches.where((s) => s.source != SandwichSource.memoix).length
                            : sandwiches.length,
                        orElse: () => 0,
                      );
                    } else if (isSmoking) {
                      final smokingAsync = ref.watch(allSmokingRecipesProvider);
                      itemCount = smokingAsync.maybeWhen(
                        data: (recipes) => hideMemoix
                            ? recipes.where((r) => r.source != SmokingSource.memoix).length
                            : recipes.length,
                        orElse: () => 0,
                      );
                    } else if (isModernist) {
                      final modernistAsync = ref.watch(allModernistRecipesProvider);
                      itemCount = modernistAsync.maybeWhen(
                        data: (recipes) => hideMemoix
                            ? recipes.where((r) => r.source != ModernistSource.memoix).length
                            : recipes.length,
                        orElse: () => 0,
                      );
                    } else if (isCheese) {
                      final cheeseAsync = ref.watch(allCheeseEntriesProvider);
                      itemCount = cheeseAsync.maybeWhen(
                        data: (entries) => hideMemoix
                            ? entries.where((e) => e.source != CheeseSource.memoix).length
                            : entries.length,
                        orElse: () => 0,
                      );
                    } else if (isCellar) {
                      final cellarAsync = ref.watch(allCellarEntriesProvider);
                      itemCount = cellarAsync.maybeWhen(
                        data: (entries) => hideMemoix
                            ? entries.where((e) => e.source != CellarSource.memoix).length
                            : entries.length,
                        orElse: () => 0,
                      );
                    } else {
                      final recipesAsync = ref.watch(
                        recipesByCourseProvider(course.slug),
                      );
                      itemCount = recipesAsync.maybeWhen(
                        data: (recipes) => hideMemoix
                            ? recipes.where((r) => r.source != RecipeSource.memoix).length
                            : recipes.length,
                        orElse: () => 0,
                      );
                    }

                    return CourseCard(
                      course: course,
                      recipeCount: itemCount,
                      onTap: () {
                        // Special course routing
                        if (course.slug == 'scratch') {
                          AppRoutes.toScratchPad(context);
                        } else if (course.slug == 'pizzas') {
                          AppRoutes.toPizzaList(context);
                        } else if (course.slug == 'sandwiches') {
                          AppRoutes.toSandwichList(context);
                        } else if (course.slug == 'smoking') {
                          AppRoutes.toSmokingList(context);
                        } else if (course.slug == 'modernist') {
                          AppRoutes.toModernistList(context);
                        } else if (course.slug == 'cheese') {
                          AppRoutes.toCheeseList(context);
                        } else if (course.slug == 'cellar') {
                          AppRoutes.toCellarList(context);
                        } else {
                          AppRoutes.toRecipeList(context, course.slug);
                        }
                      },
                    );
                  },
                  childCount: courses.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// View showing recipes organized by courses (like spreadsheet tabs)
/// DEPRECATED: Keeping for reference, but now using CourseGridView
class CourseRecipeView extends StatefulWidget {
  final List<Course> courses;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;

  const CourseRecipeView({
    super.key,
    required this.courses,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
  });

  @override
  State<CourseRecipeView> createState() => _CourseRecipeViewState();
}

class _CourseRecipeViewState extends State<CourseRecipeView> with SingleTickerProviderStateMixin {
  late TabController _courseTabController;

  @override
  void initState() {
    super.initState();
    _courseTabController = TabController(
      length: widget.courses.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _courseTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.courses.isEmpty) {
      return const Center(child: Text('No courses found'));
    }

    return Column(
      children: [
        // Course tabs (scrollable, like spreadsheet tabs at bottom)
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _courseTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: widget.courses.map((course) {
              return Tab(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: course.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: course.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(course.name),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Recipe list for selected course
        Expanded(
          child: TabBarView(
            controller: _courseTabController,
            children: widget.courses.map((course) {
              return RecipeListScreen(
                course: course.slug,
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

/// Resolve an icon name string to an IconData.
/// Used by the view override system to swap icons dynamically.
IconData _resolveIcon(String name) {
  const map = <String, IconData>{
    'search': Icons.search,
    'set_meal': Icons.set_meal,
    'restaurant': Icons.restaurant,
    'kitchen': Icons.kitchen,
    'eco': Icons.eco,
  };
  return map[name] ?? Icons.search;
}