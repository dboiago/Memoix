import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import '../widgets/modernist_card.dart';

/// Screen displaying list of modernist recipes - follows Mains pattern
class ModernistListScreen extends ConsumerStatefulWidget {
  const ModernistListScreen({super.key});

  @override
  ConsumerState<ModernistListScreen> createState() => _ModernistListScreenState();
}

class _ModernistListScreenState extends ConsumerState<ModernistListScreen> {
  Set<String> _selectedFilters = {}; // Empty = "All"
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allModernistRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'MODERNIST',
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

          // Apply hide memoix filter
          var recipes = hideMemoix
              ? allRecipes.where((r) => r.source != ModernistSource.memoix).toList()
              : allRecipes;

          // Get available filter options (technique categories)
          final availableTechniques = _getAvailableTechniques(recipes);

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

              // Filter chips (technique categories)
              if (availableTechniques.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All', recipes.length, isAllChip: true),
                      ...availableTechniques.map((technique) {
                        final count = recipes.where((r) => r.technique == technique).length;
                        return _buildFilterChip(technique, count, rawValue: technique);
                      }),
                    ],
                  ),
                ),

              // Recipe list
              Expanded(
                child: _buildRecipeList(recipes, isCompactView),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, {String? rawValue, bool isAllChip = false}) {
    final value = rawValue ?? label;
    final theme = Theme.of(context);

    // "All" is selected when no filters are selected
    final isSelected = isAllChip
        ? _selectedFilters.isEmpty
        : _selectedFilters.contains(value);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (isAllChip) {
              // Clicking "All" clears all selections
              _selectedFilters.clear();
            } else {
              // Toggle this filter
              if (_selectedFilters.contains(value)) {
                _selectedFilters.remove(value);
              } else {
                _selectedFilters.add(value);
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

  List<String> _getAvailableTechniques(List<ModernistRecipe> recipes) {
    final techniques = recipes
        .map((r) => r.technique)
        .where((t) => t != null && t.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    techniques.sort();
    return techniques;
  }

  Widget _buildRecipeList(List<ModernistRecipe> allRecipes, bool isCompact) {
    // Apply filters
    var filteredRecipes = _filterRecipes(allRecipes);

    if (filteredRecipes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        return ModernistCard(
          recipe: filteredRecipes[index],
          onTap: () => AppRoutes.toModernistDetail(context, filteredRecipes[index].id),
          isCompact: isCompact,
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
            Icons.science_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
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

  List<ModernistRecipe> _filterRecipes(List<ModernistRecipe> recipes) {
    var filtered = recipes;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            (r.technique?.toLowerCase().contains(_searchQuery) ?? false) ||
            r.equipment.any((e) => e.toLowerCase().contains(_searchQuery)) ||
            r.ingredients.any((i) => i.name.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    // Filter by technique category
    if (_selectedFilters.isNotEmpty) {
      filtered = filtered.where((r) {
        if (r.technique == null) return false;
        return _selectedFilters.contains(r.technique);
      }).toList();
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
                AppRoutes.toModernistEdit(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan from Photo'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toOCRScanner(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toURLImport(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
