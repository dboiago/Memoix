import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';
import '../widgets/pizza_card.dart';

/// Pizza list screen - displays pizzas grouped by base
class PizzaListScreen extends ConsumerStatefulWidget {
  const PizzaListScreen({super.key});

  @override
  ConsumerState<PizzaListScreen> createState() => _PizzaListScreenState();
}

class _PizzaListScreenState extends ConsumerState<PizzaListScreen> {
  PizzaBase? _selectedBase;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pizzasAsync = ref.watch(allPizzasProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PIZZAS',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: pizzasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allPizzas) {
          // Get bases that have pizzas
          final availableBases = _getAvailableBases(allPizzas);

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
                    // Get matching pizza names, cheeses, or toppings
                    final matches = <String>{};
                    for (final pizza in allPizzas) {
                      if (pizza.name.toLowerCase().contains(query)) {
                        matches.add(pizza.name);
                      }
                      for (final cheese in pizza.cheeses) {
                        if (cheese.toLowerCase().contains(query)) {
                          matches.add(cheese);
                        }
                      }
                      for (final topping in pizza.toppings) {
                        if (topping.toLowerCase().contains(query)) {
                          matches.add(topping);
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
                        hintText: 'Search pizzas...',
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

              // Base filter chips
              if (availableBases.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildBaseChip(null, allPizzas.length), // "All" chip
                      ...availableBases.map((base) {
                        final count = allPizzas.where((p) => p.base == base).length;
                        return _buildBaseChip(base, count);
                      }),
                    ],
                  ),
                ),

              // Pizza list
              Expanded(
                child: _buildPizzaList(allPizzas),
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
                AppRoutes.toPizzaEdit(context);
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

  Widget _buildBaseChip(PizzaBase? base, int count) {
    final isSelected = _selectedBase == base;
    final theme = Theme.of(context);
    final label = base?.displayName ?? 'All';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedBase = selected ? base : null);
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

  List<PizzaBase> _getAvailableBases(List<Pizza> pizzas) {
    final bases = pizzas.map((p) => p.base).toSet().toList();
    // Sort by enum order
    bases.sort((a, b) => a.index.compareTo(b.index));
    return bases;
  }

  Widget _buildPizzaList(List<Pizza> allPizzas) {
    // Filter by base
    var pizzas = _selectedBase == null
        ? allPizzas
        : allPizzas.where((p) => p.base == _selectedBase).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      pizzas = pizzas.where((p) {
        final nameMatch = p.name.toLowerCase().contains(_searchQuery);
        final cheeseMatch = p.cheeses.any((c) => c.toLowerCase().contains(_searchQuery));
        final toppingMatch = p.toppings.any((t) => t.toLowerCase().contains(_searchQuery));
        return nameMatch || cheeseMatch || toppingMatch;
      }).toList();
    }

    // Sort alphabetically by name
    pizzas.sort((a, b) => a.name.compareTo(b.name));

    if (pizzas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_pizza_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No pizzas match your search'
                  : _selectedBase != null
                      ? 'No pizzas with ${_selectedBase!.displayName} base'
                      : 'No pizzas yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isEmpty && _selectedBase == null)
              Text(
                'Tap + to add your first pizza',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
          ],
        ),
      );
    }

    // Simple flat list (no grouping headers)
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: pizzas.length,
      itemBuilder: (context, index) {
        final pizza = pizzas[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PizzaCard(
            pizza: pizza,
            onTap: () => AppRoutes.toPizzaDetail(context, pizza.uuid),
          ),
        );
      },
    );
  }
}
