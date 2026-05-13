import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../../shared/widgets/memoix_filter_chip.dart';
import '../../../shared/widgets/memoix_search_bar.dart';
import '../../mealplan/models/meal_plan.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/course.dart';
import '../models/recipe.dart';
import '../models/source_filter.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card.dart';


/// Derives the sorted cuisine list for a given course, applying the hideMemoix
/// setting. Recalculates only when the recipe list or the setting changes —
/// never on a plain setState or UI repaint (M-2).
final _availableCuisinesForCourseProvider =
    Provider.family<List<String>, String>((ref, course) {
  final hideMemoix = ref.watch(hideMemoixRecipesProvider);
  return ref.watch(recipesByCourseProvider(course)).maybeWhen(
    data: (all) {
      final recipes = hideMemoix
          ? all.where((r) => r.source != RecipeSource.memoix).toList()
          : all;
      return recipes
          .map((r) => r.cuisine)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList()
        ..sort();
    },
    orElse: () => [],
  );
});

/// Derives the sorted base-spirit list for the drinks course, applying the
/// hideMemoix setting. Recalculates only when the recipe list or the setting
/// changes — never on a plain setState or UI repaint (M-2).
final _availableBaseSpiritsForCourseProvider =
    Provider.family<List<String>, String>((ref, course) {
  final hideMemoix = ref.watch(hideMemoixRecipesProvider);
  return ref.watch(recipesByCourseProvider(course)).maybeWhen(
    data: (all) {
      final recipes = hideMemoix
          ? all.where((r) => r.source != RecipeSource.memoix).toList()
          : all;
      final bases = recipes
          .map((r) => r.subcategory)
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      bases.sort((a, b) {
        final spiritA = Spirit.lookup(a);
        final spiritB = Spirit.lookup(b);
        final aIsNonAlc = spiritA?.category == 'Non-Alcoholic';
        final bIsNonAlc = spiritB?.category == 'Non-Alcoholic';
        if (aIsNonAlc && !bIsNonAlc) return -1;
        if (!aIsNonAlc && bIsNonAlc) return 1;
        final catA = spiritA?.category ?? '';
        final catB = spiritB?.category ?? '';
        final catCompare = catA.compareTo(catB);
        if (catCompare != 0) return catCompare;
        return a.compareTo(b);
      });
      return bases;
    },
    orElse: () => [],
  );
});

/// Recipe list screen
class RecipeListScreen extends ConsumerStatefulWidget {
  final String course;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;
  final bool showAddButton;

  const RecipeListScreen({
    super.key,
    required this.course,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
    this.showAddButton = false,
  });

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final Set<String> _selectedCuisines = {}; // Empty = "All" (also used for base spirits in drinks)
  String _searchQuery = '';
  Timer? _debounce;
  List<Recipe>? _ftsResults; // null = no active search; set = debounced FTS results

  /// Check if this is the drinks course
  bool get _isDrinksScreen => widget.course.toLowerCase() == 'drinks';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Called on every search text change. Clears results immediately when the
  /// query is empty; otherwise starts a 300 ms debounce before issuing the
  /// FTS query so rapid keystrokes do not flood the database.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _ftsResults = null;
      });
      return;
    }
    setState(() => _searchQuery = trimmed);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ref
          .read(recipeRepositoryProvider)
          .searchRecipes(trimmed, courseFilter: [widget.course]);
      if (mounted) setState(() => _ftsResults = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(recipesByCourseProvider(widget.course));
    // Memoized derivations — recalculated only when the recipe list or
    // hideMemoix setting changes, not on every setState or repaint (M-2).
    final availableCuisines =
        ref.watch(_availableCuisinesForCourseProvider(widget.course));
    final availableBaseSpirits =
        ref.watch(_availableBaseSpiritsForCourseProvider(widget.course));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          Course.displayNameFromSlug(widget.course),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (allRecipes) {
          // Watch settings
          final hideMemoix = ref.watch(hideMemoixRecipesProvider);
          final isCompactView = ref.watch(compactViewProvider);
          
          // Apply source filter first, then hide memoix if enabled
          var recipes = _filterBySource(allRecipes);
          if (hideMemoix) {
            recipes = recipes.where((r) => r.source != RecipeSource.memoix).toList();
          }
          
          return Column(
            children: [
              // Search bar with autocomplete
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    final query = textEditingValue.text.toLowerCase();
                    // Get matching recipe names
                    final matches = recipes
                        .where((r) => r.name.toLowerCase().contains(query))
                        .map((r) => r.name)
                        .take(8)
                        .toList();
                    return matches;
                  },
                  onSelected: (selection) {
                    _onSearchChanged(selection.toLowerCase());
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return MemoixSearchBar(
                      hintText: 'Search recipes...',
                      controller: textController,
                      focusNode: focusNode,
                      suffixIcon: textController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                              onPressed: () {
                                textController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      onChanged: _onSearchChanged,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 200,
                            maxWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Cuisine/base filter chips (show if any exist)
              if (_isDrinksScreen && availableBaseSpirits.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ScrollConfiguration(
                    // Enable drag scrolling on all platforms without scrollbar
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: false,
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCuisineChip('All', recipes.length, isAllChip: true),
                        ...availableBaseSpirits.map((base) {
                          final count = recipes.where((r) => r.subcategory == base).length;
                          return _buildCuisineChip(Spirit.toDisplayName(base), count, rawValue: base);
                        }),
                      ],
                    ),
                  ),
                )
              else if (availableCuisines.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ScrollConfiguration(
                    // Enable drag scrolling on all platforms without scrollbar
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: false,
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCuisineChip('All', recipes.length, isAllChip: true),
                        ...availableCuisines.map((cuisine) {
                          final count = recipes.where((r) => r.cuisine?.toLowerCase() == cuisine.toLowerCase()).length;
                          return _buildCuisineChip(_displayCuisine(cuisine), count, rawValue: cuisine);
                        }),
                      ],
                    ),
                  ),
                ),

              // Recipe list
              Expanded(
                child: Builder(
                  builder: (context) {
                    // When a FTS search is active, use those results as the
                    // source list (already filtered by course). Otherwise fall
                    // back to the stream-provided course list so the cuisine
                    // chip filter can still narrow down all recipes.
                    final sourceList =
                        (_searchQuery.isNotEmpty && _ftsResults != null)
                            ? _ftsResults!
                            : recipes;
                    final filteredRecipes = _filterRecipesInMemory(sourceList);
                    if (filteredRecipes.isEmpty) {
                      return _buildEmptyState();
                    }
                    final theme = Theme.of(context);
                    return ListView.builder(
                      key: const PageStorageKey('recipe_list'),
                      padding: EdgeInsets.only(bottom: 80 + MediaQuery.paddingOf(context).bottom),
                      itemCount: filteredRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = filteredRecipes[index];
                        return Dismissible(
                          key: Key('recipe_swipe_${recipe.uuid}'),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Add to Meal Plan',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final now = DateTime.now();
                            final hour = now.hour;
                            final String course;
                            if (hour >= 5 && hour < 11) {
                              course = MealCourse.breakfast;
                            } else if (hour >= 11 && hour < 14) {
                              course = MealCourse.lunch;
                            } else if (hour >= 14 && hour < 21) {
                              course = MealCourse.dinner;
                            } else {
                              course = MealCourse.snack;
                            }
                            await ref.read(mealPlanServiceProvider).addMeal(
                              now,
                              recipeId: recipe.uuid,
                              recipeName: recipe.name,
                              course: course,
                              cuisine: recipe.cuisine,
                              recipeCategory: recipe.course,
                            );
                            MemoixSnackBar.show(
                              'Added to ${MealCourse.displayName(course)}',
                            );
                            // Return false so the item snaps back and stays in the list
                            return false;
                          },
                          child: RecipeCard(
                            recipe: recipe,
                            onTap: () => AppRoutes.toRecipeDetail(context, recipe.uuid),
                            isCompact: isCompactView,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
      },
    ),
      floatingActionButton: widget.showAddButton
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            )
          : null,
    );
  }

  Widget _buildCuisineChip(String cuisineLabel, int count, {String? rawValue, bool isAllChip = false}) {
    final value = rawValue ?? cuisineLabel;
    final isSelected = isAllChip
        ? _selectedCuisines.isEmpty
        : _selectedCuisines.contains(value);

    return MemoixFilterChip(
      value: isAllChip ? null : cuisineLabel,
      isSelected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isAllChip) {
            _selectedCuisines.clear();
          } else {
            if (_selectedCuisines.contains(value)) {
              _selectedCuisines.remove(value);
            } else {
              _selectedCuisines.add(value);
            }
          }
        });
      },
    );
  }

  List<String> _getAvailableCuisines(List<Recipe> recipes) {
    final cuisines = recipes
        .map((r) => r.cuisine)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    cuisines.sort();
    return cuisines;
  }

  /// Get available base spirits from drinks recipes
  /// Sorts with non-alcoholic first, then by category
  List<String> _getAvailableBaseSpirits(List<Recipe> recipes) {
    final bases = recipes
        .map((r) => r.subcategory)
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    
    // Sort: non-alcoholic first, then by category, then alphabetically
    bases.sort((a, b) {
      final spiritA = Spirit.lookup(a);
      final spiritB = Spirit.lookup(b);
      
      // Non-alcoholic first
      final aIsNonAlc = spiritA?.category == 'Non-Alcoholic';
      final bIsNonAlc = spiritB?.category == 'Non-Alcoholic';
      if (aIsNonAlc && !bIsNonAlc) return -1;
      if (!aIsNonAlc && bIsNonAlc) return 1;
      
      // Then by category
      final catA = spiritA?.category ?? '';
      final catB = spiritB?.category ?? '';
      final catCompare = catA.compareTo(catB);
      if (catCompare != 0) return catCompare;
      
      // Then alphabetically
      return a.compareTo(b);
    });
    
    return bases;
  }

  String _displayCuisine(String raw) {
    // Convert full names and 3-letter codes to 2-letter codes for display
    // 2-letter codes should pass through unchanged
    const map = {
      // Full country/cuisine names to 2-letter codes
      'USA': 'US',
      'United States': 'US',
      'America': 'US',
      'American': 'US',
      'Korea': 'KR',
      'Korean': 'KR',
      'South Korea': 'KR',
      'China': 'CN',
      'Chinese': 'CN',
      'Japan': 'JP',
      'Japanese': 'JP',
      'Spain': 'ES',
      'Spanish': 'ES',
      'France': 'FR',
      'French': 'FR',
      'Italy': 'IT',
      'Italian': 'IT',
      'Mexico': 'MX',
      'Mexican': 'MX',
      'Canada': 'CA',
      'Canadian': 'CA',
      'North American': 'US',
      'Thailand': 'TH',
      'Thai': 'TH',
      'India': 'IN',
      'Indian': 'IN',
      'Vietnam': 'VN',
      'Vietnamese': 'VN',
      'Greece': 'GR',
      'Greek': 'GR',
      'Germany': 'DE',
      'German': 'DE',
      'United Kingdom': 'GB',
      'British': 'GB',
      'England': 'GB',
      'English': 'GB',
      'Ireland': 'IE',
      'Irish': 'IE',
      'Portugal': 'PT',
      'Portuguese': 'PT',
      'Brazil': 'BR',
      'Brazilian': 'BR',
      'Argentina': 'AR',
      'Argentinian': 'AR',
      'Peru': 'PE',
      'Peruvian': 'PE',
      'Morocco': 'MA',
      'Moroccan': 'MA',
      'Algeria': 'DZ',
      'Algerian': 'DZ',
      'Egypt': 'EG',
      'Egyptian': 'EG',
      'Turkey': 'TR',
      'Turkish': 'TR',
      'Lebanon': 'LB',
      'Lebanese': 'LB',
      'Israel': 'IL',
      'Israeli': 'IL',
      'Indonesia': 'ID',
      'Indonesian': 'ID',
      'Malaysia': 'MY',
      'Malaysian': 'MY',
      'Philippines': 'PH',
      'Filipino': 'PH',
      'Singapore': 'SG',
      'Singaporean': 'SG',
      'Australia': 'AU',
      'Australian': 'AU',
      'New Zealand': 'NZ',
      'Caribbean': 'JM',
      'Jamaican': 'JM',
      'Cuba': 'CU',
      'Cuban': 'CU',
      'Puerto Rico': 'PR',
      'Puerto Rican': 'PR',
      'Ethiopia': 'ET',
      'Ethiopian': 'ET',
      'Nigeria': 'NG',
      'Nigerian': 'NG',
      'South Africa': 'ZA',
      'South African': 'ZA',
      'Russia': 'RU',
      'Russian': 'RU',
      'Poland': 'PL',
      'Polish': 'PL',
      'Hungary': 'HU',
      'Hungarian': 'HU',
      'Sweden': 'SE',
      'Swedish': 'SE',
      'Norway': 'NO',
      'Norwegian': 'NO',
      'Denmark': 'DK',
      'Danish': 'DK',
      'Netherlands': 'NL',
      'Dutch': 'NL',
      'Belgium': 'BE',
      'Belgian': 'BE',
      'Austria': 'AT',
      'Austrian': 'AT',
      'Switzerland': 'CH',
      'Swiss': 'CH',
      'Middle Eastern': 'ME',
      'Mediterranean': 'MD',
      'Asian': 'AS',
      'European': 'EU',
      'Latin': 'LA',
      'African': 'AF',
      'Fusion': 'FU',
    };
    return map[raw] ?? raw;
  }

  // ...existing code...

  Widget _buildEmptyState() {
    return MemoixEmptyState(
      message: widget.emptyMessage ?? 'No recipes found',
    );
  }

  List<Recipe> _filterBySource(List<Recipe> recipes) {
    switch (widget.sourceFilter) {
      case RecipeSourceFilter.memoix:
        return recipes.where((r) => r.source == RecipeSource.memoix).toList();
      case RecipeSourceFilter.personal:
        return recipes
            .where((r) =>
                r.source == RecipeSource.personal ||
                r.source == RecipeSource.imported ||
                r.source == RecipeSource.ocr ||
                r.source == RecipeSource.ai ||
                r.source == RecipeSource.url,)
            .toList();
      case RecipeSourceFilter.all:
        return recipes;
    }
  }

  /// Applies the cuisine / base-spirit chip filter to [recipes].
  ///
  /// Text search is handled via FTS5 before this method is called — this
  /// method only handles the structured chip filter.
  List<Recipe> _filterRecipesInMemory(List<Recipe> recipes) {
    var result = recipes;

    // Apply cuisine / base-spirit chip filter
    if (_selectedCuisines.isNotEmpty) {
      if (_isDrinksScreen) {
        result = result.where((r) => _selectedCuisines.contains(r.subcategory)).toList();
      } else {
        result = result.where((r) =>
            r.cuisine != null && _selectedCuisines.contains(r.cuisine),).toList();
      }
    }

    return result;
  }

    return result;
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Create Manually'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toRecipeEdit(context, course: widget.course);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toURLImport(context, course: widget.course);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan from Photo (OCR)'),
              onTap: () {
                Navigator.pop(ctx);
                // FIX: Changed from toOCRImport to toOCRScanner
                AppRoutes.toOCRScanner(context, course: widget.course);
              },
            ),
          ],
        ),
      ),
    );
  }
}
