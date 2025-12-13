import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import '../widgets/modernist_card.dart';
import 'modernist_detail_screen.dart';
import 'modernist_edit_screen.dart';

/// Screen displaying list of modernist recipes
class ModernistListScreen extends ConsumerStatefulWidget {
  const ModernistListScreen({super.key});

  @override
  ConsumerState<ModernistListScreen> createState() => _ModernistListScreenState();
}

class _ModernistListScreenState extends ConsumerState<ModernistListScreen> {
  ModernistType? _selectedType;
  String? _selectedTechnique;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allModernistRecipesProvider);
    final hideMemoix = ref.watch(hideMemoixRecipesProvider);
    final isCompact = ref.watch(compactViewProvider);

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
        data: (recipes) {
          // Apply Hide Memoix filter if enabled
          final visibleRecipes = hideMemoix
              ? recipes.where((r) => r.source != ModernistSource.memoix).toList()
              : recipes;

          if (recipes.isEmpty) {
            return _buildEmptyState(theme);
          }

          // Get available techniques from recipes
          final availableTechniques = visibleRecipes
              .map((r) => r.technique)
              .where((t) => t != null && t.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList()
            ..sort();

          // Filter recipes
          var filtered = visibleRecipes;
          if (_selectedType != null) {
            filtered = filtered.where((r) => r.type == _selectedType).toList();
          }
          if (_selectedTechnique != null) {
            filtered = filtered.where((r) => r.technique == _selectedTechnique).toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((r) =>
                r.name.toLowerCase().contains(_searchQuery) ||
                (r.technique?.toLowerCase().contains(_searchQuery) ?? false) ||
                r.equipment.any((e) => e.toLowerCase().contains(_searchQuery)) ||
                r.ingredients.any((i) => i.name.toLowerCase().contains(_searchQuery))).toList();
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search recipes, techniques, equipment...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Type filter chips
                    FilterChip(
                      label: const Text('Concept'),
                      selected: _selectedType == ModernistType.concept,
                      onSelected: (selected) => setState(() {
                        _selectedType = selected ? ModernistType.concept : null;
                      }),
                      avatar: _selectedType == ModernistType.concept
                          ? null
                          : const Icon(Icons.lightbulb_outline, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Technique'),
                      selected: _selectedType == ModernistType.technique,
                      onSelected: (selected) => setState(() {
                        _selectedType = selected ? ModernistType.technique : null;
                      }),
                      avatar: _selectedType == ModernistType.technique
                          ? null
                          : const Icon(Icons.science_outlined, size: 18),
                    ),
                    const SizedBox(width: 16),
                    // Divider
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                    const SizedBox(width: 16),
                    // Technique category chips
                    ...availableTechniques.map((technique) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(technique),
                        selected: _selectedTechnique == technique,
                        onSelected: (selected) => setState(() {
                          _selectedTechnique = selected ? technique : null;
                        }),
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Recipe count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} recipe${filtered.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedType != null || _selectedTechnique != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedType = null;
                          _selectedTechnique = null;
                        }),
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),

              // Recipe list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching recipes',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final recipe = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ModernistCard(
                              recipe: recipe,
                              isCompact: isCompact,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ModernistDetailScreen(recipeId: recipe.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModernistEditScreen()),
        ),
        backgroundColor: MemoixColors.modernist,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No modernist recipes yet',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first molecular gastronomy recipe',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModernistEditScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Recipe'),
          ),
        ],
      ),
    );
  }
}
