import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';
import '../widgets/smoking_card.dart';
import 'smoking_detail_screen.dart';
import 'smoking_edit_screen.dart';

/// Screen displaying list of smoking recipes grouped by wood type
class SmokingListScreen extends ConsumerStatefulWidget {
  const SmokingListScreen({super.key});

  @override
  ConsumerState<SmokingListScreen> createState() => _SmokingListScreenState();
}

class _SmokingListScreenState extends ConsumerState<SmokingListScreen> {
  WoodType? _selectedWood;
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
        title: const Text('Smoking'),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recipes) {
          if (recipes.isEmpty) {
            return _buildEmptyState(theme);
          }

          // Get available woods
          final availableWoods = recipes.map((r) => r.wood).toSet().toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));

          // Filter recipes
          var filtered = recipes;
          if (_selectedWood != null) {
            filtered = filtered.where((r) => r.wood == _selectedWood).toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((r) =>
                r.name.toLowerCase().contains(_searchQuery) ||
                r.woodDisplayName.toLowerCase().contains(_searchQuery)).toList();
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search smoking recipes...',
                    prefixIcon: const Icon(Icons.search),
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
                ),
              ),

              // Wood filter chips
              if (availableWoods.length > 1)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildWoodChip(null, 'All', filtered.length),
                      ...availableWoods.map((wood) {
                        final count = recipes.where((r) => r.wood == wood).length;
                        return _buildWoodChip(wood, wood.displayName, count);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNew(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWoodChip(WoodType? wood, String label, int count) {
    final theme = Theme.of(context);
    final isSelected = _selectedWood == wood;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedWood = wood),
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

  void _createNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmokingEditScreen(),
      ),
    );
  }
}
