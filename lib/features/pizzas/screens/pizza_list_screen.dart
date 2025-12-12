import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
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
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search pizzas...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
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
        onPressed: () => AppRoutes.toPizzaEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Pizza'),
        backgroundColor: MemoixColors.pizzas,
        foregroundColor: Colors.white,
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
        selectedColor: MemoixColors.pizzas.withOpacity(0.3),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected
              ? theme.colorScheme.onSecondaryContainer
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

    // Group by base if showing all
    if (_selectedBase == null && _searchQuery.isEmpty) {
      return _buildGroupedList(pizzas);
    }

    // Simple list otherwise
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

  Widget _buildGroupedList(List<Pizza> pizzas) {
    // Group pizzas by base
    final grouped = <PizzaBase, List<Pizza>>{};
    for (final pizza in pizzas) {
      grouped.putIfAbsent(pizza.base, () => []).add(pizza);
    }

    // Sort groups by base enum order
    final sortedBases = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sortedBases.length,
      itemBuilder: (context, groupIndex) {
        final base = sortedBases[groupIndex];
        final basePizzas = grouped[base]!;
        basePizzas.sort((a, b) => a.name.compareTo(b.name));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: MemoixColors.pizzas.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      base.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: MemoixColors.pizzas,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${basePizzas.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            // Pizza cards
            ...basePizzas.map((pizza) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PizzaCard(
                    pizza: pizza,
                    onTap: () => AppRoutes.toPizzaDetail(context, pizza.uuid),
                  ),
                )),
          ],
        );
      },
    );
  }
}
