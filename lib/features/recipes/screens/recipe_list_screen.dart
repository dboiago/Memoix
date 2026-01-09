import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../mealplan/models/meal_plan.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/course.dart';
import '../models/recipe.dart';
import '../models/source_filter.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card.dart';


/// Recipe list screen matching Figma design
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

  /// Check if this is the drinks course
  bool get _isDrinksScreen => widget.course.toLowerCase() == 'drinks';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(
      recipesByCourseProvider(widget.course),
    );

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
          
          // Get cuisines that actually exist in this recipe set
          final availableCuisines = _getAvailableCuisines(recipes);
          
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
                    setState(() => _searchQuery = selection.toLowerCase());
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                                onPressed: () {
                                  textController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
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
              if (_isDrinksScreen && _getAvailableBaseSpirits(recipes).isNotEmpty)
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
                        ..._getAvailableBaseSpirits(recipes).map((base) {
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
                child: FutureBuilder<List<Recipe>>(
                  future: _searchRecipes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final filteredRecipes = snapshot.data ?? [];
                    if (filteredRecipes.isEmpty) {
                      return _buildEmptyState();
                    }
                    final theme = Theme.of(context);
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = filteredRecipes[index];
                        return Dismissible(
                          key: Key('recipe_swipe_${recipe.uuid}'),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            color: theme.colorScheme.primary.withOpacity(0.2),
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
                          child: RecipeCard(
                            recipe: recipe,
                            onTap: () => AppRoutes.toRecipeDetail(context, recipe.uuid),
                            isCompact: ref.watch(compactViewProvider),
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
    final theme = Theme.of(context);
    
    // "All" is selected when no cuisines are selected
    final isSelected = isAllChip 
        ? _selectedCuisines.isEmpty 
        : _selectedCuisines.contains(value);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(cuisineLabel),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (isAllChip) {
              // Clicking "All" clears all selections
              _selectedCuisines.clear();
            } else {
              // Toggle this cuisine
              if (_selectedCuisines.contains(value)) {
                _selectedCuisines.remove(value);
              } else {
                _selectedCuisines.add(value);
              }
            }
          });
        },
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
        showCheckmark: false,
        side: BorderSide(
          color: isSelected 
              ? theme.colorScheme.secondary 
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected 
              ? theme.colorScheme.secondary 
              : theme.colorScheme.onSurface,
        ),
      ),
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
                r.source == RecipeSource.url,)
            .toList();
      case RecipeSourceFilter.all:
        return recipes;
    }
  }

  Future<List<Recipe>> _searchRecipes() async {
    // If searching from "All Recipes" or similar, pass null for course filter
    final courseFilter = widget.course.toLowerCase() == 'all' ? null : [widget.course];
    return await ref.read(recipeRepositoryProvider).searchRecipes(_searchQuery, courseFilter: courseFilter);
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
