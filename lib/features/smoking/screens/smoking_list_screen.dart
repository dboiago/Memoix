import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';
import '../widgets/smoking_card.dart';
import 'smoking_detail_screen.dart';
import 'smoking_edit_screen.dart';

/// Screen displaying list of smoking recipes grouped by category
class SmokingListScreen extends ConsumerStatefulWidget {
  const SmokingListScreen({super.key});

  @override
  ConsumerState<SmokingListScreen> createState() => _SmokingListScreenState();
}

class _SmokingListScreenState extends ConsumerState<SmokingListScreen> {
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allSmokingRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SMOKING',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recipes) {
          if (recipes.isEmpty) {
            return _buildEmptyState(theme);
          }

          // Get available categories from recipes
          final availableCategories = recipes
              .map((r) => r.category)
              .where((c) => c != null && c.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList()
            ..sort((a, b) => a.compareTo(b));

          // Filter recipes
          var filtered = recipes;
          if (_selectedCategory != null) {
            filtered = filtered.where((r) => r.category == _selectedCategory).toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((r) =>
                r.name.toLowerCase().contains(_searchQuery) ||
                (r.item?.toLowerCase().contains(_searchQuery) ?? false) ||
                (r.category?.toLowerCase().contains(_searchQuery) ?? false) ||
                r.wood.toLowerCase().contains(_searchQuery)).toList();
          }

          return Column(
            children: [
              // Search bar with autocomplete
              Padding(
                padding: const EdgeInsets.all(16),
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    final query = textEditingValue.text.toLowerCase();
                    // Get matching recipe names, items, woods, or seasonings
                    final matches = <String>{};
                    for (final recipe in recipes) {
                      if (recipe.name.toLowerCase().contains(query)) {
                        matches.add(recipe.name);
                      }
                      if (recipe.item != null && recipe.item!.toLowerCase().contains(query)) {
                        matches.add(recipe.item!);
                      }
                      if (recipe.wood.toLowerCase().contains(query)) {
                        matches.add(recipe.wood);
                      }
                      for (final seasoning in recipe.seasonings) {
                        if (seasoning.name.toLowerCase().contains(query)) {
                          matches.add(seasoning.name);
                        }
                      }
                    }
                    return matches.take(8).toList();
                  },
                  onSelected: (selection) {
                    setState(() => _searchQuery = selection.toLowerCase());
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search smoking recipes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
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

              // Category filter chips
              if (availableCategories.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip(null, 'All', filtered.length),
                      ...availableCategories.map((category) {
                        final count = recipes.where((r) => r.category == category).length;
                        return _buildCategoryChip(category, category, count);
                      }),
                    ],
                  ),
                ),

              // Recipe list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No recipes found',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final recipe = filtered[index];
                          return SmokingCard(
                            recipe: recipe,
                            onTap: () => _openDetail(recipe),
                          );
                        },
                      ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SmokingEditScreen(),
                  ),
                );
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
                AppRoutes.toSmokingURLImport(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label, int count) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category;
    final dotColor = category != null 
        ? MemoixColors.forSmokedItemDot(category) 
        : null;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: dotColor != null
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.outdoor_grill,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No smoking recipes yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first smoked recipe',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(SmokingRecipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmokingDetailScreen(recipeId: recipe.uuid),
      ),
    );
  }
}
