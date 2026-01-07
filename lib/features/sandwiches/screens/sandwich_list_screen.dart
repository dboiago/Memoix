import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
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
  final Set<String> _selectedProteins = {}; // empty = All

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
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          // "All" chip
          _buildFilterChip(
            label: 'All',
            isSelected: _selectedProteins.isEmpty,
            theme: theme,
            onSelected: (_) {
              setState(() => _selectedProteins.clear());
            },
          ),

          // "Cheese" chip for vegetarian (no proteins)
          if (hasVegetarian)
            _buildFilterChip(
              label: 'Cheese',
              isSelected: _selectedProteins.contains('cheese'),
              theme: theme,
              onSelected: (_) {
                setState(() {
                  if (_selectedProteins.contains('cheese')) {
                    _selectedProteins.remove('cheese');
                  } else {
                    _selectedProteins.add('cheese');
                  }
                });
              },
            ),

          // "Assorted" chip for multi-protein sandwiches
          if (hasAssorted)
            _buildFilterChip(
              label: 'Assorted',
              isSelected: _selectedProteins.contains('assorted'),
              theme: theme,
              onSelected: (_) {
                setState(() {
                  if (_selectedProteins.contains('assorted')) {
                    _selectedProteins.remove('assorted');
                  } else {
                    _selectedProteins.add('assorted');
                  }
                });
              },
            ),

          // Individual protein chips
          ...proteins.map((protein) {
            final proteinKey = protein.toLowerCase();
            final isSelected = _selectedProteins.contains(proteinKey);
            return _buildFilterChip(
              label: protein,
              isSelected: isSelected,
              theme: theme,
              onSelected: (_) {
                setState(() {
                  if (_selectedProteins.contains(proteinKey)) {
                    _selectedProteins.remove(proteinKey);
                  } else {
                    _selectedProteins.add(proteinKey);
                  }
                });
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
    required ThemeData theme,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
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

    // Filter by selected proteins (multi-select)
    if (_selectedProteins.isNotEmpty) {
      sandwiches = sandwiches.where((s) {
        // Check each selected filter
        for (final filter in _selectedProteins) {
          if (filter == 'cheese') {
            // Vegetarian: no proteins but has cheese
            if (s.proteins.isEmpty && s.cheeses.isNotEmpty) return true;
          } else if (filter == 'assorted') {
            // Assorted: multiple proteins
            if (s.proteins.length > 1) return true;
          } else {
            // Has specific protein
            if (s.proteins.any((p) => p.toLowerCase() == filter)) return true;
          }
        }
        return false;
      }).toList();
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
      return MemoixEmptyState(
        message: _searchQuery.isNotEmpty || _selectedProteins.isNotEmpty
            ? 'No sandwiches match your filters'
            : 'No sandwiches yet',
        subtitle: _searchQuery.isEmpty && _selectedProteins.isEmpty
            ? 'Tap + to add your first sandwich'
            : null,
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
