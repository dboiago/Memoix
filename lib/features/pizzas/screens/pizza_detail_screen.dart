import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';

/// Pizza detail screen - displays pizza info with cheeses, toppings, and notes
class PizzaDetailScreen extends ConsumerWidget {
  final String pizzaId;

  const PizzaDetailScreen({super.key, required this.pizzaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pizzasAsync = ref.watch(allPizzasProvider);

    return pizzasAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (pizzas) {
        final pizza = pizzas.firstWhere(
          (p) => p.uuid == pizzaId,
          orElse: () => Pizza()..name = '',
        );

        if (pizza.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Pizza not found')),
          );
        }

        return _PizzaDetailView(pizza: pizza);
      },
    );
  }
}

class _PizzaDetailView extends ConsumerWidget {
  final Pizza pizza;

  const _PizzaDetailView({required this.pizza});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: pizza.imageUrl != null ? 250 : 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pizza.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                ),
              ),
              background: _buildHeaderBackground(theme),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  pizza.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: pizza.isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  ref.read(pizzaRepositoryProvider).toggleFavorite(pizza);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Base badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MemoixColors.pizzas.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_pizza,
                          size: 18,
                          color: MemoixColors.pizzas,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pizza.base.displayName} Base',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: MemoixColors.pizzas,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cheeses section
                  if (pizza.cheeses.isNotEmpty) ...[
                    _buildSectionHeader(theme, 'Cheeses'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pizza.cheeses
                          .map((cheese) => _buildIngredientChip(theme, cheese, isCheesey: true))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Toppings section
                  if (pizza.toppings.isNotEmpty) ...[
                    _buildSectionHeader(theme, 'Toppings'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pizza.toppings
                          .map((topping) => _buildIngredientChip(theme, topping, isCheesey: false))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Notes section
                  if (pizza.notes != null && pizza.notes!.isNotEmpty) ...[
                    _buildSectionHeader(theme, 'Notes'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pizza.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRoutes.toPizzaEdit(context, pizzaId: pizza.uuid),
        icon: const Icon(Icons.edit),
        label: const Text('Edit'),
        backgroundColor: MemoixColors.pizzas,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    if (pizza.imageUrl == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MemoixColors.pizzas.withOpacity(0.6),
              MemoixColors.pizzas.withOpacity(0.3),
            ],
          ),
        ),
      );
    }

    // Check if it's a URL or local file
    if (pizza.imageUrl!.startsWith('http://') || pizza.imageUrl!.startsWith('https://')) {
      return Image.network(
        pizza.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    } else {
      return Image.file(
        File(pizza.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildIngredientChip(ThemeData theme, String label, {required bool isCheesey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCheesey
            ? Colors.amber.withOpacity(0.15)
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCheesey
              ? Colors.amber.withOpacity(0.4)
              : theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isCheesey
              ? Colors.amber.shade800
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'edit':
        AppRoutes.toPizzaEdit(context, pizzaId: pizza.uuid);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Pizza?'),
            content: Text('Are you sure you want to delete "${pizza.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(pizzaRepositoryProvider).deletePizza(pizza.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${pizza.name} deleted')),
            );
          }
        }
        break;
    }
  }
}
