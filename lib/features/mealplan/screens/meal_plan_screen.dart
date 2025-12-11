import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/meal_plan.dart';
import '../../../core/providers.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/models/recipe.dart';
import '../../shopping/screens/shopping_list_screen.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late PageController _pageController;
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _pageController = PageController(initialPage: 1000); // Start in "middle"
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime _getWeekForPage(int page) {
    final weeksFromStart = page - 1000;
    return _currentWeekStart.add(Duration(days: weeksFromStart * 7));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: () {
              _pageController.animateToPage(
                1000,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Generate shopping list',
            onPressed: () => _generateShoppingList(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigation header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final week = ref.watch(selectedWeekProvider);
                    final weekEnd = week.add(const Duration(days: 6));
                    final format = DateFormat('MMM d');
                    return Text(
                      '${format.format(week)} - ${format.format(weekEnd)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
            ),
          ),
          // Week view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                final weekStart = _getWeekForPage(page);
                ref.read(selectedWeekProvider.notifier).state = weekStart;
              },
              itemBuilder: (context, page) {
                final weekStart = _getWeekForPage(page);
                return WeekView(weekStart: weekStart);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMeal(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _generateShoppingList(BuildContext context) {
    // Generate shopping list from the currently selected week
    final weekStart = ref.read(selectedWeekProvider);
    final mealService = ref.read(mealPlanServiceProvider);
    final repo = ref.read(recipeRepositoryProvider);

    // Async generate and navigate to the new list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating shopping list from meal plan...')),
    );

    mealService.getWeek(weekStart).then((weekly) async {
      final ids = weekly.allRecipeIds.toList();
      final recipes = <Recipe>[];
      for (final id in ids) {
        final r = await repo.getRecipeByUuid(id);
        if (r != null) recipes.add(r);
      }
      if (recipes.isNotEmpty) {
        final shoppingService = ref.read(shoppingListServiceProvider);
        final list = await shoppingService.generateFromRecipes(recipes);
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recipes found for this week')));
        }
      }
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate shopping list: $e')));
    });
  }

  void _addMeal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const AddMealSheet(),
    );
  }
}

class WeekView extends ConsumerWidget {
  final DateTime weekStart;

  const WeekView({super.key, required this.weekStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use FutureProvider which loads immediately
    final weekPlanAsync = ref.watch(weeklyPlanProvider(weekStart));

    return weekPlanAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading meal plan'),
            const SizedBox(height: 8),
            Text('$err', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      data: (weeklyPlan) {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: 7,
          itemBuilder: (context, dayIndex) {
            final date = weekStart.add(Duration(days: dayIndex));
            final plan = weeklyPlan.planForDay(dayIndex);
            return DayCard(date: date, plan: plan);
          },
        );
      },
    );
  }
}

class DayCard extends ConsumerWidget {
  final DateTime date;
  final MealPlan? plan;

  const DayCard({super.key, required this.date, this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isToday = _isToday(date);
    final dayFormat = DateFormat('EEEE');
    final dateFormat = DateFormat('MMM d');

    return Card(
      elevation: isToday ? 2 : 0,
      color: isToday ? theme.colorScheme.surfaceContainerHighest : null,
      child: ExpansionTile(
        initiallyExpanded: isToday,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
        title: Text(
          dayFormat.format(date),
          style: TextStyle(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          plan != null && !plan!.isEmpty
              ? '${plan!.mealCount} meal${plan!.mealCount == 1 ? '' : 's'} planned'
              : 'No meals planned',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (plan == null || plan!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tap + to add a meal'),
            )
          else
            ...MealCourse.all.map((course) {
              final meals = plan!.getMeals(course);
              if (meals.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      MealCourse.displayName(course),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...meals.map((meal) => Dismissible(
                    key: Key('${date.toIso8601String()}_${course}_${meal.recipeId ?? meal.recipeName}'),
                    background: Container(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(Icons.delete, color: theme.colorScheme.secondary),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      // Remove the meal from the plan
                      ref.read(mealPlanServiceProvider).removeMeal(date, meals.indexOf(meal));
                    },
                    child: ListTile(
                      dense: true,
                      title: Text(meal.recipeName ?? 'Unknown'),
                      subtitle: _buildMealSubtitle(meal, theme),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (action) {
                          if (action == 'remove') {
                            // Remove the meal
                            ref.read(mealPlanServiceProvider).removeMeal(date, meals.indexOf(meal));
                          } else if (action == 'view') {
                            // Navigate to recipe detail
                            if (meal.recipeId != null) {
                              Navigator.pushNamed(
                                context,
                                '/recipe/${meal.recipeId}',
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility),
                                SizedBox(width: 8),
                                Text('View Recipe'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: theme.colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text('Remove', style: TextStyle(color: theme.colorScheme.secondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to recipe detail
                        if (meal.recipeId != null) {
                          Navigator.pushNamed(
                            context,
                            '/recipe/${meal.recipeId}',
                          );
                        }
                      },
                    ),
                  )),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget? _buildMealSubtitle(PlannedMeal meal, ThemeData theme) {
    final parts = <String>[];
    if (meal.cuisine != null && meal.cuisine!.isNotEmpty) {
      parts.add(meal.cuisine!);
    }
    if (meal.recipeCategory != null && meal.recipeCategory!.isNotEmpty) {
      // Capitalize first letter of category slug
      final categoryDisplay = meal.recipeCategory![0].toUpperCase() + meal.recipeCategory!.substring(1);
      parts.add(categoryDisplay);
    }
    
    if (parts.isEmpty) {
      return meal.servings != null
          ? Text('${meal.servings} servings', style: theme.textTheme.labelSmall)
          : null;
    }
    
    final subtitle = parts.join(' • ');
    if (meal.servings != null) {
      return Text('$subtitle • ${meal.servings} servings', style: theme.textTheme.labelSmall);
    }
    return Text(subtitle, style: theme.textTheme.labelSmall);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class AddMealSheet extends ConsumerStatefulWidget {
  const AddMealSheet({super.key});

  @override
  ConsumerState<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<AddMealSheet> {
  DateTime _selectedDate = DateTime.now();
  String _selectedCourse = MealCourse.dinner;
  final _searchController = TextEditingController();
  List<Recipe> _suggestions = [];

  void _onSearchChanged(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final repo = ref.read(recipeRepositoryProvider);
    final results = await repo.searchRecipes(q);
    setState(() => _suggestions = results.take(3).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add to Meal Plan',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Date selector
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEEE, MMM d').format(_selectedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              // Course selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: MealCourse.all.map((course) {
                    final isSelected = _selectedCourse == course;
                    return ChoiceChip(
                      label: Text(
                        '${MealCourse.emoji(course)} ${MealCourse.displayName(course)}',
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCourse = course);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Recipe search/selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select a Recipe',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search recipes...',
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 8),
              // Search suggestions and favourites in scrollable area
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final favouritesAsync = ref.watch(favoriteRecipesProvider);
                    return ListView(
                      controller: scrollController,
                      children: [
                        // Search suggestions
                        if (_suggestions.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'Search Results',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          ..._suggestions.map((r) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(r.name),
                            subtitle: r.cuisine != null ? Text(r.cuisine!) : null,
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () async {
                              await ref.read(mealPlanServiceProvider).addMeal(
                                _selectedDate,
                                recipeId: r.uuid,
                                recipeName: r.name,
                                course: _selectedCourse,
                                cuisine: r.cuisine,
                                recipeCategory: r.course,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${r.name}')));
                              }
                            },
                          )),
                          const Divider(),
                        ],
                        // Favourites section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Favourites',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        favouritesAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (err, _) => Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text('Error: $err')),
                          ),
                          data: (favourites) {
                            if (favourites.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('No favourites yet.\nMark recipes as favourites to see them here.'),
                                ),
                              );
                            }
                            return Column(
                              children: favourites.map((recipe) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(recipe.name.isNotEmpty ? recipe.name[0].toUpperCase() : '?'),
                                ),
                                title: Text(recipe.name),
                                subtitle: recipe.cuisine != null ? Text(recipe.cuisine!) : null,
                                trailing: const Icon(Icons.add_circle_outline),
                                onTap: () async {
                                  await ref.read(mealPlanServiceProvider).addMeal(
                                    _selectedDate,
                                    recipeId: recipe.uuid,
                                    recipeName: recipe.name,
                                    course: _selectedCourse,
                                    cuisine: recipe.cuisine,
                                    recipeCategory: recipe.course,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${recipe.name}')),
                                    );
                                  }
                                },
                              )).toList(),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
