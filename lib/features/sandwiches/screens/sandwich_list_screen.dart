import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/sandwich.dart';
import '../repository/sandwich_repository.dart';
import '../widgets/sandwich_card.dart';

/// Sandwich list screen - displays sandwiches with search and protein filters
class SandwichListScreen extends ConsumerStatefulWidget {
  const SandwichListScreen({super.key});

  @override
  ConsumerState<SandwichListScreen> createState() => _SandwichListScreenState();
}

class _SandwichListScreenState extends ConsumerState<SandwichListScreen> {
  String _searchQuery = '';
  String? _selectedProtein; // null = All, 'cheese' = vegetarian, otherwise protein name

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sandwichesAsync = ref.watch(allSandwichesProvider);
    final hideMemoix = ref.watch(hideMemoixRecipesProvider);
    final isCompact = ref.watch(compactViewProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Sandwiches',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: sandwichesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allSandwiches) {
          // Apply Hide Memoix filter if enabled
          final visibleSandwiches = hideMemoix
              ? allSandwiches.where((s) => s.source != SandwichSource.memoix).toList()
              : allSandwiches;

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
                    // Get matching names, breads, proteins, cheeses, condiments
                    final matches = <String>{};
                    for (final sandwich in visibleSandwiches) {
                      if (sandwich.name.toLowerCase().contains(query)) {
                        matches.add(sandwich.name);
                      }
                      if (sandwich.bread.toLowerCase().contains(query)) {
                        matches.add(sandwich.bread);
                      }
                      for (final protein in sandwich.proteins) {
                        if (protein.toLowerCase().contains(query)) {
                          matches.add(protein);
                        }
                      }
                      for (final cheese in sandwich.cheeses) {
                        if (cheese.toLowerCase().contains(query)) {
                          matches.add(cheese);
                        }
                      }
                      for (final condiment in sandwich.condiments) {
                        if (condiment.toLowerCase().contains(query)) {
                          matches.add(condiment);
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
                        hintText: 'Search sandwiches...',
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

              // Protein filter chips
              _buildProteinFilterChips(visibleSandwiches, theme),

              // Sandwich list
              Expanded(
                child: _buildSandwichList(visibleSandwiches, isCompact),
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
                AppRoutes.toSandwichEdit(context);
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

  Widget _buildProteinFilterChips(List<Sandwich> sandwiches, ThemeData theme) {
    // Collect unique proteins from all sandwiches and track special categories
    final proteinSet = <String>{};
    bool hasVegetarian = false;
    bool hasAssorted = false;

    for (final sandwich in sandwiches) {
      if (sandwich.proteins.isEmpty && sandwich.cheeses.isNotEmpty) {
        hasVegetarian = true;
      }
      if (sandwich.proteins.length > 1) {
        hasAssorted = true;
      }
      for (final protein in sandwich.proteins) {
        proteinSet.add(protein);
      }
    }

    final proteins = proteinSet.toList()..sort();

    if (proteins.isEmpty && !hasVegetarian) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" chip
          _buildFilterChip(
            label: 'All',
            isSelected: _selectedProtein == null,
            dotColor: null,
            theme: theme,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedProtein = null);
              }
            },
          ),

          // "Cheese" chip for vegetarian (no proteins)
          if (hasVegetarian)
            _buildFilterChip(
              label: 'Cheese',
              isSelected: _selectedProtein == 'cheese',
              dotColor: MemoixColors.cheese,
              theme: theme,
              onSelected: (selected) {
                setState(() => _selectedProtein = selected ? 'cheese' : null);
              },
            ),

          // "Assorted" chip for multi-protein sandwiches
          if (hasAssorted)
            _buildFilterChip(
              label: 'Assorted',
              isSelected: _selectedProtein == 'assorted',
              dotColor: MemoixColors.sandwiches,
              theme: theme,
              onSelected: (selected) {
                setState(() => _selectedProtein = selected ? 'assorted' : null);
              },
            ),

          // Individual protein chips
          ...proteins.map((protein) {
            final isSelected = _selectedProtein == protein.toLowerCase();
            return _buildFilterChip(
              label: protein,
              isSelected: isSelected,
              dotColor: MemoixColors.forProteinDot(protein),
              theme: theme,
              onSelected: (selected) {
                setState(() => _selectedProtein = selected ? protein.toLowerCase() : null);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? dotColor,
    required ThemeData theme,
    required ValueChanged<bool> onSelected,
  }) {
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
        onSelected: onSelected,
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

  Widget _buildSandwichList(List<Sandwich> allSandwiches, bool isCompact) {
    var sandwiches = allSandwiches;

    // Filter by selected protein
    if (_selectedProtein != null) {
      if (_selectedProtein == 'cheese') {
        // Vegetarian: no proteins but has cheese
        sandwiches = sandwiches.where((s) => s.proteins.isEmpty && s.cheeses.isNotEmpty).toList();
      } else if (_selectedProtein == 'assorted') {
        // Assorted: multiple proteins
        sandwiches = sandwiches.where((s) => s.proteins.length > 1).toList();
      } else {
        // Has specific protein (includes assorted sandwiches that contain this protein)
        sandwiches = sandwiches.where((s) => 
          s.proteins.any((p) => p.toLowerCase() == _selectedProtein!.toLowerCase())
        ).toList();
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      sandwiches = sandwiches.where((s) {
        final nameMatch = s.name.toLowerCase().contains(_searchQuery);
        final breadMatch = s.bread.toLowerCase().contains(_searchQuery);
        final proteinMatch = s.proteins.any((p) => p.toLowerCase().contains(_searchQuery));
        final vegetableMatch = s.vegetables.any((v) => v.toLowerCase().contains(_searchQuery));
        final cheeseMatch = s.cheeses.any((c) => c.toLowerCase().contains(_searchQuery));
        final condimentMatch = s.condiments.any((c) => c.toLowerCase().contains(_searchQuery));
        return nameMatch || breadMatch || proteinMatch || vegetableMatch || cheeseMatch || condimentMatch;
      }).toList();
    }

    // Sort alphabetically by name
    sandwiches.sort((a, b) => a.name.compareTo(b.name));

    if (sandwiches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lunch_dining,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedProtein != null
                  ? 'No sandwiches match your filters'
                  : 'No sandwiches yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isEmpty && _selectedProtein == null)
              Text(
                'Tap + to add your first sandwich',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
          ],
        ),
      );
    }

    // Simple flat list
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sandwiches.length,
      itemBuilder: (context, index) {
        final sandwich = sandwiches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SandwichCard(
            sandwich: sandwich,
            isCompact: isCompact,
            onTap: () => AppRoutes.toSandwichDetail(context, sandwich.uuid),
          ),
        );
      },
    );
  }
}
