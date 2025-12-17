import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/category.dart';
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
          Category.displayNameFromSlug(widget.course),
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
                child: _buildRecipeList(recipes),
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
      // 3-letter and full names to 2-letter codes
      'USA': 'US',
      'United States': 'US',
      'America': 'US',
      'American': 'US',
      'Korea': 'KR',
      'Korean': 'KR',
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
    };
    return map[raw] ?? raw;
  }

  Widget _buildRecipeList(List<Recipe> allRecipes) {
    // Apply filters
    final filteredRecipes = _filterRecipes(allRecipes);

    if (filteredRecipes.isEmpty) {
      return _buildEmptyState();
    }

    // Simple list without grouping for cleaner UI
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        return RecipeCard(
          recipe: filteredRecipes[index],
          onTap: () => AppRoutes.toRecipeDetail(context, filteredRecipes[index].uuid),
          isCompact: ref.watch(compactViewProvider),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyMessage ?? 'No recipes found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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

  List<Recipe> _filterRecipes(List<Recipe> recipes) {
    var filtered = recipes;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            (r.cuisine?.toLowerCase().contains(_searchQuery) ?? false) ||
            (r.subcategory?.toLowerCase().contains(_searchQuery) ?? false) ||
            (r.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)));
      }).toList();
    }

    // Filter by base spirit (for drinks) or cuisine (for food)
    if (_selectedCuisines.isNotEmpty) {
      if (_isDrinksScreen) {
        // Filter by base spirit (stored in subcategory)
        filtered = filtered.where((r) {
          if (r.subcategory == null) return false;
          return _selectedCuisines.any((c) => r.subcategory == c);
        }).toList();
      } else {
        // Filter by cuisine
        filtered = filtered.where((r) {
          if (r.cuisine == null) return false;
          return _selectedCuisines.any((c) => r.cuisine!.toLowerCase() == c.toLowerCase());
        }).toList();
      }
    }

    return filtered;
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
              title: const Text('Create New Recipe'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toRecipeEdit(context, course: widget.course);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan from Photo'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toOCRScanner(context, course: widget.course);
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
