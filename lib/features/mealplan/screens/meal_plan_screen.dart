import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/meal_plan.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/models/cuisine.dart';
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
  DateTime? _selectedDate; // Sticky selected date, null means use today

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

  /// Get the effective selected date (defaults to today if none selected)
  DateTime get _effectiveSelectedDate => _selectedDate ?? DateTime.now();

  /// Select a date (sticky until week change or navigation away)
  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
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
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${format.format(week)} - ${format.format(weekEnd)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                // Reset selected date when changing weeks
                setState(() => _selectedDate = null);
              },
              itemBuilder: (context, page) {
                final weekStart = _getWeekForPage(page);
                return WeekView(
                  weekStart: weekStart,
                  selectedDate: _effectiveSelectedDate,
                  onDateSelected: _selectDate,
                );
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
    MemoixSnackBar.show('Generating shopping list from meal plan...');

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
        MemoixSnackBar.showError('No recipes found for this week');
      }
    }).catchError((e) {
      MemoixSnackBar.showError('Failed to generate shopping list: $e');
    });
  }

  void _addMeal(BuildContext context) {
    // Use the sticky selected date (defaults to today if not set)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddMealSheet(initialDate: _effectiveSelectedDate),
    );
  }
}

class WeekView extends ConsumerWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekView({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.onDateSelected,
  });

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
            const Text('Error loading meal plan'),
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
            final isSelected = _isSameDay(date, selectedDate);
            return DayCard(
              date: date,
              plan: plan,
              isSelected: isSelected,
              onSelect: () => onDateSelected(date),
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class DayCard extends ConsumerStatefulWidget {
  final DateTime date;
  final MealPlan? plan;
  final bool isSelected;
  final VoidCallback onSelect;

  const DayCard({
    super.key,
    required this.date,
    this.plan,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  ConsumerState<DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<DayCard> {
  bool _hovered = false;
  static const _undoDuration = Duration(seconds: 4);

  @override
  void deactivate() {
    // Reset hover state when navigating away
    _hovered = false;
    super.deactivate();
  }

  /// Generate a unique key for a meal delete operation
  /// Use meal properties instead of index to handle multiple pending deletes
  String _mealKey(String course, int index) {
    final courseMeals = widget.plan?.getMeals(course) ?? [];
    if (index >= courseMeals.length) return '${widget.date.toIso8601String()}_${course}_$index';
    
    final meal = courseMeals[index];
    // Create a stable key using meal properties (not index)
    final recipeKey = meal.recipeId ?? meal.recipeName ?? 'unknown';
    return '${widget.date.toIso8601String()}_${course}_$recipeKey';
  }

  void _startDeleteTimer(String course, int index) {
    final mealService = ref.read(mealPlanServiceProvider);
    
    // Find the actual meal index in the full meals array
    final courseMeals = widget.plan?.getMeals(course) ?? [];
    if (index >= courseMeals.length) return;
    
    final allMeals = widget.plan?.meals ?? [];
    int actualIndex = -1;
    int courseCount = 0;
    for (int i = 0; i < allMeals.length; i++) {
      if (allMeals[i].course == course) {
        if (courseCount == index) {
          actualIndex = i;
          break;
        }
        courseCount++;
      }
    }
    
    if (actualIndex == -1) return;
    
    final key = _mealKey(course, index);
    
    // Schedule delete at service level (persists across widget rebuilds)
    mealService.scheduleMealDelete(
      date: widget.date,
      mealIndex: actualIndex,
      key: key,
      undoDuration: _undoDuration,
      onComplete: () {
        // Refresh the UI after delete completes (only if still mounted)
        if (mounted) {
          ref.invalidate(weeklyPlanProvider);
        }
      },
    );
    
    // Trigger rebuild to show pending state
    setState(() {});
  }

  void _undoDelete(String course, int index) {
    final key = _mealKey(course, index);
    ref.read(mealPlanServiceProvider).cancelPendingDelete(key);
    setState(() {});
  }

  bool _isPendingDelete(String course, int index) {
    final key = _mealKey(course, index);
    return ref.read(mealPlanServiceProvider).isPendingDelete(key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isToday(widget.date);
    final isHighlighted = widget.isSelected || isToday || _hovered;
    final dayFormat = DateFormat('EEEE');
    final dateFormat = DateFormat('MMM d');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isHighlighted
                ? theme.colorScheme.secondary
                : theme.colorScheme.outline.withValues(alpha: 0.1),
            width: isHighlighted ? 1.5 : 1.0,
          ),
        ),
        color: widget.isSelected 
            ? theme.colorScheme.secondary.withOpacity(0.08)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: widget.isSelected || isToday,
            onExpansionChanged: (_) {
              // Select this date when tapped/expanded
              widget.onSelect();
            },
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.date.day.toString(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
            title: Text(
              dayFormat.format(widget.date),
              style: TextStyle(
                fontWeight: widget.isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              widget.plan != null && !widget.plan!.isEmpty
                  ? '${widget.plan!.mealCount} meal${widget.plan!.mealCount == 1 ? '' : 's'} planned'
                  : 'No meals planned',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            children: [
              if (widget.plan == null || widget.plan!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tap + to add a meal'),
                )
              else
                ...MealCourse.all.map((course) {
                  final meals = widget.plan!.getMeals(course);
              if (meals.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          MealCourse.displayName(course),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nutrition summary for this meal course
                        _MealCourseNutritionChip(meals: meals),
                      ],
                    ),
                  ),
                  ...meals.asMap().entries.map((entry) {
                    final mealIndex = entry.key;
                    final meal = entry.value;
                    
                    // Show inline undo placeholder if pending delete
                    if (_isPendingDelete(course, mealIndex)) {
                      return Container(
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${meal.recipeName ?? "Meal"} removed',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _undoDelete(course, mealIndex),
                              child: Text(
                                'UNDO',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      );
                    }
                    
                    return Dismissible(
                    key: Key('${widget.date.toIso8601String()}_${course}_${meal.recipeId ?? meal.recipeName}_$mealIndex'),
                    background: Container(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(Icons.delete, color: theme.colorScheme.secondary),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      // Start inline undo timer instead of immediate delete
                      _startDeleteTimer(course, mealIndex);
                      return false; // Don't dismiss - show placeholder instead
                    },
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        meal.recipeName ?? 'Unknown',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            // Cuisine with continent-colored dot
                            if (meal.cuisine != null && meal.cuisine!.isNotEmpty) ...[
                              Text(
                                '\u2022',
                                style: TextStyle(
                                  color: MemoixColors.forContinentDot(meal.cuisine),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                Cuisine.toAdjective(meal.cuisine),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Category (Apps, Mains, Drinks, etc.)
                            if (meal.recipeCategory != null && meal.recipeCategory!.isNotEmpty) ...[
                              Text(
                                _capitalizeFirst(meal.recipeCategory!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onSelected: (action) async {
                          if (action == 'remove') {
                            // Use inline undo instead of immediate delete
                            _startDeleteTimer(course, mealIndex);
                          } else if (action == 'view') {
                            // Navigate to recipe detail using AppRoutes
                            if (meal.recipeId != null) {
                              AppRoutes.toRecipeDetail(context, meal.recipeId!);
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
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Color(0xFFA88FA8)),
                                SizedBox(width: 8),
                                Text('Remove', style: TextStyle(color: Color(0xFFA88FA8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to recipe detail using AppRoutes
                        if (meal.recipeId != null) {
                          AppRoutes.toRecipeDetail(context, meal.recipeId!);
                        }
                      },
                    ),
                  );
                  }),
                ],
              );
            }),
          ],
        ),
        ),
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

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class AddMealSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  
  const AddMealSheet({super.key, this.initialDate});

  @override
  ConsumerState<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<AddMealSheet> {
  late DateTime _selectedDate;
  String _selectedCourse = MealCourse.dinner;
  final _searchController = TextEditingController();
  List<Recipe> _suggestions = [];
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final repo = ref.read(recipeRepositoryProvider);
    final results = await repo.searchRecipes(q);
    setState(() => _suggestions = results.take(3).toList());
  }

  /// Add recipe to meal plan without closing the sheet
  Future<void> _addRecipeToMealPlan(Recipe recipe) async {
    await ref.read(mealPlanServiceProvider).addMeal(
      _selectedDate,
      recipeId: recipe.uuid,
      recipeName: recipe.name,
      course: _selectedCourse,
      cuisine: recipe.cuisine,
      recipeCategory: recipe.course,
    );
    
    // Only show feedback if still mounted
    if (!mounted) return;
    
    // Show SnackBar first (no rebuild yet)
    MemoixSnackBar.show('Added ${recipe.name}');
    
    // Delay invalidate to next frame to avoid rebuilding during SnackBar animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(weeklyPlanProvider);
      }
    });
    
    // Clear search and keep sheet open for adding more recipes
    _searchController.clear();
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
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
                              onTap: () {
                                // Cache context before async operations
                                final navigator = Navigator.of(context);
                                _addRecipeToMealPlan(r);
                              },
                            ),),
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
                                  onTap: () {
                                    // Cache context before async operations
                                    final navigator = Navigator.of(context);
                                    _addRecipeToMealPlan(recipe);
                                  },
                                ),).toList(),
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
      ),
    );
  }
}
/// Widget that shows total calories for the week's meal plan
class _WeeklyNutritionChip extends ConsumerWidget {
  final DateTime weekStart;

  const _WeeklyNutritionChip({required this.weekStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekPlanAsync = ref.watch(weeklyPlanProvider(weekStart));
    
    return weekPlanAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (weeklyPlan) {
        // Get all recipe IDs for the week
        final recipeIds = weeklyPlan.allRecipeIds;
        if (recipeIds.isEmpty) return const SizedBox.shrink();
        
        // Calculate total calories from recipes
        return _NutritionSummaryChip(recipeIds: recipeIds.toList());
      },
    );
  }
}

/// Widget that shows calories for meals in a specific course (Breakfast, Lunch, Dinner, etc.)
class _MealCourseNutritionChip extends ConsumerWidget {
  final List<PlannedMeal> meals;

  const _MealCourseNutritionChip({required this.meals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allRecipesProvider);
    
    // Extract recipe IDs from meals
    final recipeIds = meals
        .where((m) => m.recipeId != null)
        .map((m) => m.recipeId!)
        .toList();
    
    if (recipeIds.isEmpty) return const SizedBox.shrink();
    
    return recipesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allRecipes) {
        int totalCalories = 0;
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;
        
        for (final id in recipeIds) {
          final recipe = allRecipes.firstWhere(
            (r) => r.uuid == id,
            orElse: () => Recipe()..name = '',
          );
          if (recipe.nutrition != null && recipe.nutrition!.hasData) {
            if (recipe.nutrition!.calories != null) {
              totalCalories += recipe.nutrition!.calories!;
            }
            if (recipe.nutrition!.proteinContent != null) {
              totalProtein += recipe.nutrition!.proteinContent!;
            }
            if (recipe.nutrition!.carbohydrateContent != null) {
              totalCarbs += recipe.nutrition!.carbohydrateContent!;
            }
            if (recipe.nutrition!.fatContent != null) {
              totalFat += recipe.nutrition!.fatContent!;
            }
          }
        }
        
        if (totalCalories == 0) return const SizedBox.shrink();
        
        return Tooltip(
          message: '${totalProtein.round()}g protein, ${totalCarbs.round()}g carbs, ${totalFat.round()}g fat',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, size: 12, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '$totalCalories cal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Chip that calculates and displays total nutrition for a list of recipes
class _NutritionSummaryChip extends ConsumerWidget {
  final List<String> recipeIds;

  const _NutritionSummaryChip({required this.recipeIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allRecipesProvider);
    
    return recipesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allRecipes) {
        // Find recipes and sum up nutrition
        int totalCalories = 0;
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;
        int recipesWithNutrition = 0;
        
        for (final id in recipeIds) {
          final recipe = allRecipes.firstWhere(
            (r) => r.uuid == id,
            orElse: () => Recipe()..name = '',
          );
          if (recipe.nutrition != null && recipe.nutrition!.hasData) {
            recipesWithNutrition++;
            if (recipe.nutrition!.calories != null) {
              totalCalories += recipe.nutrition!.calories!;
            }
            if (recipe.nutrition!.proteinContent != null) {
              totalProtein += recipe.nutrition!.proteinContent!;
            }
            if (recipe.nutrition!.carbohydrateContent != null) {
              totalCarbs += recipe.nutrition!.carbohydrateContent!;
            }
            if (recipe.nutrition!.fatContent != null) {
              totalFat += recipe.nutrition!.fatContent!;
            }
          }
        }
        
        if (totalCalories == 0) return const SizedBox.shrink();
        
        return Tooltip(
          message: 'Total: ${totalProtein.round()}g protein, ${totalCarbs.round()}g carbs, ${totalFat.round()}g fat\n($recipesWithNutrition of ${recipeIds.length} recipes have nutrition data)',
          child: ActionChip(
            avatar: Icon(Icons.local_fire_department, size: 16, color: theme.colorScheme.primary),
            label: Text('$totalCalories cal'),
            visualDensity: VisualDensity.compact,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            onPressed: () => _showNutritionDetails(
              context,
              totalCalories: totalCalories,
              totalProtein: totalProtein,
              totalCarbs: totalCarbs,
              totalFat: totalFat,
              recipesWithNutrition: recipesWithNutrition,
              totalRecipes: recipeIds.length,
            ),
          ),
        );
      },
    );
  }

  void _showNutritionDetails(
    BuildContext context, {
    required int totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    required int recipesWithNutrition,
    required int totalRecipes,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Nutrition Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nutritionRow('Calories', '$totalCalories'),
            _nutritionRow('Protein', '${totalProtein.round()}g'),
            _nutritionRow('Carbohydrates', '${totalCarbs.round()}g'),
            _nutritionRow('Fat', '${totalFat.round()}g'),
            const SizedBox(height: 16),
            Text(
              '$recipesWithNutrition of $totalRecipes recipes have nutrition data.\nValues are estimates per serving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}