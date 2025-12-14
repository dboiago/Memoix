import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shopping_list.dart';
import '../../../core/providers.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/models/recipe.dart';
import '../../mealplan/models/meal_plan.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(shoppingListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Lists'),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No shopping lists yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generate one from your meal plan\nor selected recipes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ShoppingListCard(list: list);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => const CreateShoppingListSheet(),
    );
  }
}

class ShoppingListCard extends StatelessWidget {
  final ShoppingList list;

  const ShoppingListCard({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = list.items.isEmpty ? 0.0 : list.checkedCount / list.items.length;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (list.isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Complete',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                '${list.checkedCount} of ${list.items.length} items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShoppingListDetailScreen extends ConsumerWidget {
  final String listUuid;

  const ShoppingListDetailScreen({super.key, required this.listUuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listsAsync = ref.watch(shoppingListsProvider);

    return listsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (lists) {
        final list = lists.firstWhere(
          (l) => l.uuid == listUuid,
          orElse: () => ShoppingList()..name = 'Not Found',
        );

        if (list.name == 'Not Found') {
          return Scaffold(
            appBar: AppBar(title: const Text('List Not Found')),
            body: const Center(child: Text('This shopping list no longer exists.')),
          );
        }

        final grouped = list.groupedItems;
        final categories = grouped.keys.toList()..sort();

        return Scaffold(
          appBar: AppBar(
            title: Text(list.name),
            actions: [
              // Nutrition summary chip if list has recipe IDs
              if (list.recipeIds.isNotEmpty)
                _ShoppingListNutritionChip(recipeIds: list.recipeIds),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareList(context, list),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value, list),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'clear', child: Text('Clear Checked')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                  ),
                ],
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, catIndex) {
              final category = categories[catIndex];
              final items = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      category,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  // Items
                  ...items.asMap().entries.map((entry) {
                    final itemIndex = list.items.indexOf(entry.value);
                    return _ShoppingItemTile(
                      item: entry.value,
                      onToggle: () async {
                        await ref.read(shoppingListServiceProvider).toggleItem(list, itemIndex);
                      },
                      onDelete: () async {
                        await ref.read(shoppingListServiceProvider).removeItem(list, itemIndex);
                      },
                    );
                  }),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addItem(context, ref, list),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _shareList(BuildContext context, ShoppingList list) {
    // Share as text
    final buffer = StringBuffer();
    buffer.writeln('🛒 ${list.name}');
    buffer.writeln();
    
    for (final category in list.groupedItems.keys) {
      buffer.writeln('$category:');
      for (final item in list.groupedItems[category]!) {
        final check = item.isChecked ? '✓' : '○';
        final amount = item.amount != null ? '${item.amount} ' : '';
        buffer.writeln('  $check $amount${item.name}');
      }
      buffer.writeln();
    }
    
    // Use share_plus to share
    // Share.share(buffer.toString());
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, ShoppingList list) {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, ref, list);
        break;
      case 'clear':
        // Clear checked items
        final checkedIndices = <int>[];
        for (int i = list.items.length - 1; i >= 0; i--) {
          if (list.items[i].isChecked) {
            checkedIndices.add(i);
          }
        }
        for (final i in checkedIndices) {
          ref.read(shoppingListServiceProvider).removeItem(list, i);
        }
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete List?'),
            content: Text('Delete "${list.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(shoppingListServiceProvider).delete(list.id);
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.secondary),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _addItem(BuildContext context, WidgetRef ref, ShoppingList list) {
    showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(
        onAdd: (item) {
          ref.read(shoppingListServiceProvider).addItem(list, item);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, ShoppingList list) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'List Name',
            hintText: 'Enter a name for this list',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(shoppingListServiceProvider).rename(list, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ShoppingItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('${item.name}-${item.amount}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.secondary),
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (_) => onToggle(),
        ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                color: item.isChecked
                    ? theme.colorScheme.onSurface.withAlpha((0.5 * 255).round())
                    : null,
              ),
            ),
        subtitle: item.amount != null
            ? Text(
                item.amount!,
                style: TextStyle(
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: item.recipeSource != null
            ? Tooltip(
                message: 'From: ${item.recipeSource}',
                child: Icon(
                  Icons.restaurant,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              )
            : null,
        onTap: onToggle,
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final void Function(ShoppingItem item) onAdd;

  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g., Milk',
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (optional)',
                hintText: 'e.g., 2 gallons',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final item = ShoppingItem.create(
                name: _nameController.text.trim(),
                amount: _amountController.text.trim().isEmpty
                    ? null
                    : _amountController.text.trim(),
              );
              widget.onAdd(item);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class CreateShoppingListSheet extends ConsumerStatefulWidget {
  const CreateShoppingListSheet({super.key});

  @override
  ConsumerState<CreateShoppingListSheet> createState() => _CreateShoppingListSheetState();
}

class _CreateShoppingListSheetState extends ConsumerState<CreateShoppingListSheet> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Shopping List ${DateTime.now().month}/${DateTime.now().day}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Shopping List',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'List Name',
              hintText: 'Enter a name for this list',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('From Meal Plan'),
            subtitle: const Text('Generate from this week\'s meals'),
            onTap: () async {
              final name = _nameController.text.trim();
              Navigator.pop(context);
              final weekStart = ref.read(selectedWeekProvider);
              final mealService = ref.read(mealPlanServiceProvider);
              final repo = ref.read(recipeRepositoryProvider);
              final weekly = await mealService.getWeek(weekStart);
              final ids = weekly.allRecipeIds.toList();
              final recipes = <Recipe>[];
              for (final id in ids) {
                final r = await repo.getRecipeByUuid(id);
                if (r != null) recipes.add(r);
              }
              if (recipes.isNotEmpty) {
                final list = await ref.read(shoppingListServiceProvider).generateFromRecipes(recipes, name: name.isNotEmpty ? name : null);
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)));
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recipes found to generate list')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('From Recipes'),
            subtitle: const Text('Select recipes to shop for'),
            onTap: () {
              final name = _nameController.text.trim();
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _RecipeSelectorScreen(
                    listName: name.isNotEmpty ? name : null,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Empty List'),
            subtitle: const Text('Start with a blank list'),
            onTap: () async {
              final name = _nameController.text.trim();
              Navigator.pop(context);
              final list = await ref.read(shoppingListServiceProvider).createEmpty(name: name.isNotEmpty ? name : null);
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)));
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Screen for selecting multiple recipes to generate a shopping list
class _RecipeSelectorScreen extends ConsumerStatefulWidget {
  final String? listName;

  const _RecipeSelectorScreen({this.listName});

  @override
  ConsumerState<_RecipeSelectorScreen> createState() => _RecipeSelectorScreenState();
}

class _RecipeSelectorScreenState extends ConsumerState<_RecipeSelectorScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedRecipeIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Recipes'),
        actions: [
          if (_selectedRecipeIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_selectedRecipeIds.length} selected',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search recipes...',
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // Recipe list
          Expanded(
            child: recipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (recipes) {
                // Filter by search
                final filtered = _searchQuery.isEmpty
                    ? recipes
                    : recipes.where((r) =>
                        r.name.toLowerCase().contains(_searchQuery) ||
                        (r.cuisine?.toLowerCase().contains(_searchQuery) ?? false) ||
                        r.course.toLowerCase().contains(_searchQuery),
                      ).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No recipes found' : 'No matching recipes',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];
                    final isSelected = _selectedRecipeIds.contains(recipe.uuid);

                    return ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleRecipe(recipe.uuid),
                      ),
                      title: Text(
                        recipe.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (recipe.cuisine != null) recipe.cuisine,
                          recipe.course,
                        ].join(' • '),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Text(
                        '${recipe.ingredients.length} items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      onTap: () => _toggleRecipe(recipe.uuid),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedRecipeIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _generateList(context),
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Generate List (${_selectedRecipeIds.length} recipes)'),
                ),
              ),
            )
          : null,
    );
  }

  void _toggleRecipe(String uuid) {
    setState(() {
      if (_selectedRecipeIds.contains(uuid)) {
        _selectedRecipeIds.remove(uuid);
      } else {
        _selectedRecipeIds.add(uuid);
      }
    });
  }

  Future<void> _generateList(BuildContext context) async {
    if (_selectedRecipeIds.isEmpty) return;

    final repo = ref.read(recipeRepositoryProvider);
    final recipes = <Recipe>[];
    
    for (final id in _selectedRecipeIds) {
      final r = await repo.getRecipeByUuid(id);
      if (r != null) recipes.add(r);
    }

    if (recipes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recipes found')),
        );
      }
      return;
    }

    final list = await ref.read(shoppingListServiceProvider).generateFromRecipes(
      recipes,
      name: widget.listName,
    );

    if (context.mounted) {
      // Pop the selector and navigate to the new list
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)),
      );
    }
  }
}

/// Chip that displays total nutrition for recipes in a shopping list
class _ShoppingListNutritionChip extends ConsumerWidget {
  final List<String> recipeIds;

  const _ShoppingListNutritionChip({required this.recipeIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(allRecipesProvider);
    
    return recipesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allRecipes) {
        // Find recipes and sum up nutrition
        int totalCalories = 0;
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;
        int recipesWithNutrition = 0;
        
        for (final id in recipeIds) {
          final recipe = allRecipes.firstWhere(
            (r) => r.uuid == id,
            orElse: () => Recipe()..name = '',
          );
          if (recipe.nutrition != null && recipe.nutrition!.hasData) {
            recipesWithNutrition++;
            if (recipe.nutrition!.calories != null) {
              totalCalories += recipe.nutrition!.calories!;
            }
            if (recipe.nutrition!.proteinContent != null) {
              totalProtein += recipe.nutrition!.proteinContent!;
            }
            if (recipe.nutrition!.carbohydrateContent != null) {
              totalCarbs += recipe.nutrition!.carbohydrateContent!;
            }
            if (recipe.nutrition!.fatContent != null) {
              totalFat += recipe.nutrition!.fatContent!;
            }
          }
        }
        
        if (totalCalories == 0) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: '${totalProtein.round()}g protein, ${totalCarbs.round()}g carbs, ${totalFat.round()}g fat',
            child: ActionChip(
              avatar: Icon(Icons.local_fire_department, size: 16, color: theme.colorScheme.primary),
              label: Text('$totalCalories cal'),
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              onPressed: () => _showNutritionDetails(
                context,
                totalCalories: totalCalories,
                totalProtein: totalProtein,
                totalCarbs: totalCarbs,
                totalFat: totalFat,
                recipesWithNutrition: recipesWithNutrition,
                totalRecipes: recipeIds.length,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNutritionDetails(
    BuildContext context, {
    required int totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    required int recipesWithNutrition,
    required int totalRecipes,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Nutrition Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nutritionRow('Calories', '$totalCalories'),
            _nutritionRow('Protein', '${totalProtein.round()}g'),
            _nutritionRow('Carbohydrates', '${totalCarbs.round()}g'),
            _nutritionRow('Fat', '${totalFat.round()}g'),
            const SizedBox(height: 16),
            Text(
              '$recipesWithNutrition of $totalRecipes recipes have nutrition data.\nValues are estimates per serving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}