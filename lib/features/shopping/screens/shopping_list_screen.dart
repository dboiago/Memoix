import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../../core/database/app_database.dart' hide Recipe, Ingredient, Course;
import '../models/shopping_list_item.dart';
import '../../../core/utils/ingredient_categorizer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/memoix_snackbar.dart';
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
            return const MemoixEmptyState(
              message: 'No shopping lists yet',
              subtitle: 'Generate one from your meal plan\nor selected recipes',
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

class ShoppingListCard extends ConsumerStatefulWidget {
  final ShoppingList list;

  const ShoppingListCard({super.key, required this.list});

  @override
  ConsumerState<ShoppingListCard> createState() => _ShoppingListCardState();
}

class _ShoppingListCardState extends ConsumerState<ShoppingListCard> {
  bool _isPendingDelete = false;
  static const _undoDuration = Duration(seconds: 4);

  void _startDeleteTimer() {
    ref.read(shoppingListServiceProvider).scheduleListDelete(
      listId: widget.list.id,
      undoDuration: _undoDuration,
      onComplete: () {
        if (mounted) {
          setState(() => _isPendingDelete = false);
        }
      },
    );
    setState(() => _isPendingDelete = true);
  }

  void _undoDelete() {
    ref.read(shoppingListServiceProvider).cancelPendingDelete(widget.list.id);
    setState(() => _isPendingDelete = false);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Delete "${widget.list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startDeleteTimer();
              unawaited(SupabaseSyncService.notifyDeleted('shopping_lists', widget.list.uuid));
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(shoppingItemsProvider(widget.list.id));
    final items = itemsAsync.valueOrNull ?? const [];
    final itemCount = items.length;
    final checkedCount = items.where((i) => i.isChecked).length;
    final progress = itemCount == 0 ? 0.0 : checkedCount / itemCount;
    final isPendingDelete =
      _isPendingDelete || ref.read(shoppingListServiceProvider).isPendingDelete(widget.list.id);

    // Show inline undo placeholder when pending delete
    if (isPendingDelete) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          height: 88, // Match approximate height of normal card
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.list.name} deleted',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: _undoDelete,
                child: Text(
                  'UNDO',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal state: show dismissible card
    return Dismissible(
      key: Key('shopping_list_${widget.list.uuid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.secondary),
      ),
      confirmDismiss: (direction) async {
        // Start inline undo timer instead of immediate delete
        _startDeleteTimer();
        return false; // Don't dismiss - show placeholder instead
      },
      child: Card(
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShoppingListDetailScreen(listUuid: widget.list.uuid),
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
                        widget.list.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.list.completedAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Complete',
                          style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Delete list',
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.secondary),
                      onPressed: () => _confirmDelete(context),
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
                  '$checkedCount of $itemCount items',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
        final list = lists.where((l) => l.uuid == listUuid).firstOrNull;

        if (list == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('List Not Found')),
            body: const Center(child: Text('This shopping list no longer exists.')),
          );
        }

        final decodedRecipeIds = (jsonDecode(list.recipeIds) as List).cast<String>();
        return Scaffold(
          appBar: AppBar(
            title: Text(list.name),
            actions: [
              if (decodedRecipeIds.isNotEmpty)
                _ShoppingListNutritionChip(recipeIds: decodedRecipeIds),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareList(context, ref, list),
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
          body: _ShoppingListDetailBody(list: list),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addItem(context, ref, list),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _shareList(BuildContext context, WidgetRef ref, ShoppingList list) async {
    final items = await ref.read(databaseProvider).shoppingDao.getItemsForList(list.id);
    final buffer = StringBuffer();
    buffer.writeln('Shopping List: ${list.name}');
    buffer.writeln();

    for (final item in items) {
      final check = item.isChecked ? '[x]' : '[ ]';
      final amount = item.amount != null ? '${item.amount} ' : '';
      buffer.writeln('$check $amount${item.name}');
    }

    // Use share_plus to share
    // Share.share(buffer.toString());
  }

  Future<void> _handleMenuAction(BuildContext context, WidgetRef ref, String action, ShoppingList list) async {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, ref, list);
        break;
      case 'clear':
        final currentItems = await ref.read(databaseProvider).shoppingDao.getItemsForList(list.id);
        final checkedUuids = currentItems
            .where((i) => i.isChecked && i.uuid.isNotEmpty)
            .map((i) => i.uuid)
            .toList();
        ShoppingList? latest;
        for (final itemUuid in checkedUuids) {
          latest = await ref.read(shoppingListServiceProvider).removeItemById(list, itemUuid) ?? latest;
        }
        if (latest != null) {
          await _reportShoppingListSaved(ref, latest, 'manual_save');
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
        onAdd: (item) async {
          try {
            final updated = await ref.read(shoppingListServiceProvider).addItem(list, item);
            // Pop dialog immediately so the user sees the result
            if (ctx.mounted) Navigator.pop(ctx);
            if (updated != null) {
              // Report asynchronously — don't block the UI
              _reportShoppingListSaved(ref, updated, 'manual_save');
            }
          } catch (e) {
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              MemoixSnackBar.showError('Failed to add item');
            }
          }
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

class _ShoppingListDetailBody extends ConsumerWidget {
  final ShoppingList list;

  const _ShoppingListDetailBody({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingItemsProvider(list.id));
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => _buildList(context, ref, items),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<ShoppingItem> items) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in items) {
      final cat = item.category ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: grouped.entries.map((entry) {
        final category = entry.key;
        final catItems = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryHeader(title: category),
            ...catItems.map((item) {
              final itemUuid = item.uuid;
              final itemIndex = items.indexOf(item);
              return _ShoppingItemTile(
                item: item,
                onToggle: () async {
                  final result = await ref.read(shoppingListServiceProvider).toggleItemById(
                    list,
                    itemUuid,
                    fallbackIndex: itemIndex,
                  );
                },
                onDelete: () async {
                  await ref.read(shoppingListServiceProvider).scheduleItemDelete(
                    listId: list.id,
                    itemUuid: itemUuid,
                    itemName: item.name,
                    itemAmount: item.amount,
                    itemRecipeSource: item.recipeSource,
                    fallbackIndex: itemIndex,
                    undoDuration: _ShoppingItemTileState.undoDuration,
                  );
                },
                onUndo: () {
                  ref.read(shoppingListServiceProvider).cancelPendingItemDelete(
                    listId: list.id,
                    itemUuid: itemUuid,
                    fallbackIndex: itemIndex,
                  );
                },
                isPendingDelete: () {
                  return ref.read(shoppingListServiceProvider).isPendingItemDelete(
                    listId: list.id,
                    itemUuid: itemUuid,
                    fallbackIndex: itemIndex,
                  );
                },
                onEditAmount: () => _editItemAmount(context, ref, item),
                onRecipeTap: item.recipeSource != null && item.recipeSource!.isNotEmpty
                    ? () => _navigateToRecipe(context, ref, item.recipeSource!)
                    : null,
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  void _editItemAmount(BuildContext context, WidgetRef ref, ShoppingItem item) {
    final controller = TextEditingController(text: item.amount ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Amount: ${item.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: 'e.g., 2 Tbsp',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final updated = await ref
                  .read(shoppingListServiceProvider)
                  .updateItemAmountById(list, item.uuid, controller.text);
              if (updated != null) {
                await _reportShoppingListSaved(ref, updated, 'manual_save');
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToRecipe(BuildContext context, WidgetRef ref, String recipeSource) async {
    final names = recipeSource.split(', ').where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) return;

    final repo = ref.read(recipeRepositoryProvider);

    if (names.length == 1) {
      final results = await repo.searchRecipes(names.first);
      final match = results.where(
        (r) => r.name.toLowerCase() == names.first.toLowerCase(),
      ).firstOrNull;
      if (match != null && context.mounted) {
        AppRoutes.toRecipeDetail(context, match.uuid);
      }
    } else {
      if (!context.mounted) return;
      final theme = Theme.of(context);
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'From Recipes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...names.map((name) => ListTile(
                title: Text(name),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                onTap: () async {
                  Navigator.pop(ctx);
                  final results = await repo.searchRecipes(name);
                  final match = results.where(
                    (r) => r.name.toLowerCase() == name.toLowerCase(),
                  ).firstOrNull;
                  if (match != null && context.mounted) {
                    AppRoutes.toRecipeDetail(context, match.uuid);
                  }
                },
              ),),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ShoppingItemTile extends StatefulWidget {
  final ShoppingItem item;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;
  final VoidCallback onUndo;
  final bool Function() isPendingDelete;
  final VoidCallback? onRecipeTap;
  final VoidCallback? onEditAmount;

  const _ShoppingItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onUndo,
    required this.isPendingDelete,
    this.onRecipeTap,
    this.onEditAmount,
  });

  @override
  State<_ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<_ShoppingItemTile> {
  bool _isPendingDelete = false;
  Timer? _undoTimer;
  static const undoDuration = Duration(seconds: 4);

  Future<void> _startDeleteTimer() async {
    await widget.onDelete();
    if (mounted) {
      setState(() => _isPendingDelete = true);
      _undoTimer?.cancel();
      _undoTimer = Timer(undoDuration, () {
        if (mounted) {
          setState(() => _isPendingDelete = false);
        }
      });
    }
  }

  void _undoDelete() {
    widget.onUndo();
    _undoTimer?.cancel();
    setState(() => _isPendingDelete = false);
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show inline undo placeholder when pending delete
    final isPending = _isPendingDelete;
    if (isPending) {
      return Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.item.name} deleted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: _undoDelete,
              child: Text(
                'UNDO',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(widget.item.uuid),
      // Bi-directional swipe
      direction: DismissDirection.horizontal,
      // Left-to-right: check/uncheck (primary background)
      background: Container(
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          widget.item.isChecked ? Icons.remove_done : Icons.check,
          color: theme.colorScheme.primary,
        ),
      ),
      // Right-to-left: delete (secondary background)
      secondaryBackground: Container(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.secondary),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Left-to-right: toggle check state, don't dismiss
          await widget.onToggle();
          return false;
        } else {
          // Right-to-left: start inline undo timer
          await _startDeleteTimer();
          return false; // Don't dismiss - show placeholder instead
        }
      },
      child: ListTile(
        leading: Checkbox(
          value: widget.item.isChecked,
          onChanged: (_) {
            widget.onToggle();
          },
        ),
            title: Text(
              pluralizeIngredient(
                widget.item.name,
                IngredientService().classify(widget.item.name),
              ),
              style: TextStyle(
                decoration: widget.item.isChecked ? TextDecoration.lineThrough : null,
                color: widget.item.isChecked
                    ? theme.colorScheme.onSurface.withAlpha((0.5 * 255).round())
                    : null,
              ),
            ),
        subtitle: widget.item.amount != null
            ? Text(
                widget.item.amount!,
                style: TextStyle(
                  decoration: widget.item.isChecked ? TextDecoration.lineThrough : null,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: widget.item.recipeSource != null && widget.onRecipeTap != null
            ? GestureDetector(
                onTap: widget.onRecipeTap,
                child: Tooltip(
                  message: 'From: ${widget.item.recipeSource}',
                  child: Icon(
                    Icons.restaurant,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : widget.item.recipeSource != null
                ? Tooltip(
                    message: 'From: ${widget.item.recipeSource}',
                    child: Icon(
                      Icons.restaurant,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                  )
                : null,
        onTap: () {
          widget.onToggle();
        },
        onLongPress: widget.onEditAmount,
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final Future<void> Function(ShoppingItem item) onAdd;

  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

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
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() => _isSubmitting = true);
                    final item = ShoppingItem(
                      id: 0,
                      shoppingListId: 0,
                      uuid: '',
                      name: _nameController.text.trim(),
                      amount: _amountController.text.trim().isEmpty
                          ? null
                          : _amountController.text.trim(),
                      unit: null,
                      category: null,
                      recipeSource: null,
                      isChecked: false,
                      manualNotes: null,
                    );
                    await widget.onAdd(item);
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
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
                await _reportShoppingListCreated(ref, list, 'meal_plan');
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)));
                }
              } else {
                MemoixSnackBar.showError('No recipes found to generate list');
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
              await _reportShoppingListCreated(ref, list, 'empty');
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
    // Select only fields used by this picker (uuid, name, cuisine, course,
    // ingredientCount) — avoids rebuilds from unrelated recipe field changes.
    final recipesAsync = ref.watch(
      allRecipesProvider.select(
        (v) => v.whenData(
          (list) => list
              .map((r) => (
                uuid: r.uuid,
                name: r.name,
                cuisine: r.cuisine,
                course: r.course,
                ingredientCount: r.ingredients.length,
              ),)
              .toList(),
        ),
      ),
    );

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
                        '${recipe.ingredientCount} items',
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
      MemoixSnackBar.showError('No recipes found');
      return;
    }

    final list = await ref.read(shoppingListServiceProvider).generateFromRecipes(
      recipes,
      name: widget.listName,
    );
    await _reportShoppingListCreated(ref, list, 'recipes');

    if (context.mounted) {
      // Pop the selector and navigate to the new list
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ShoppingListDetailScreen(listUuid: list.uuid)),
      );
    }
  }
}

// From the poet would come the first book,
// The mentor would honour their legacy,
// From this would come a place to cook.
// 
// The hall exalted for gastronomy,
// The musician would shun convention,
// They would devote themselves to agronomy.
// 
// His sequence would cause apprehension,
// But became his ultimate ascension.
const _foundation = 'Bvreawe kwi vvoujgk ms ri xni rfdx uj ik ppr.';

Future<void> _reportShoppingListCreated(
  WidgetRef ref,
  ShoppingList list,
  String source,
) async {
  final items = await ref.read(databaseProvider).shoppingDao.getItemsForList(list.id);
  int produce = 0, meat = 0, dairy = 0, pantry = 0, other = 0;
  for (final item in items) {
    final cat = (item.category ?? '').toLowerCase();
    if (cat.contains('produce') || cat.contains('fruit') || cat.contains('vegetable')) {
      produce++;
    } else if (cat.contains('meat') || cat.contains('seafood') || cat.contains('poultry')) {
      meat++;
    } else if (cat.contains('dairy')) {
      dairy++;
    } else if (cat.contains('pantry') || cat.contains('spice') || cat.contains('baking')) {
      pantry++;
    } else {
      other++;
    }
  }
  
  await IntegrityService.reportEvent(
    'activity.shopping_list_created',
    metadata: {
      'source': source,
      'item_count': items.length,
      'recipe_count': (jsonDecode(list.recipeIds) as List).length,
      'produce_count': produce,
      'meat_count': meat,
      'dairy_count': dairy,
      'pantry_count': pantry,
      'other_count': other,
    },
  );
  await processIntegrityResponses(ref);
}

Future<void> _reportShoppingListSaved(
  WidgetRef ref,
  ShoppingList list,
  String source,
) async {
  await _reportShoppingListCreated(ref, list, source);
}

/// Chip that displays total nutrition for recipes in a shopping list
class _ShoppingListNutritionChip extends ConsumerWidget {
  final List<String> recipeIds;

  const _ShoppingListNutritionChip({required this.recipeIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final recipeIdSet = recipeIds.toSet();

    // Select only nutrition primitives for the shopping list's recipe IDs.
    final nutritionData = ref.watch(
      allRecipesProvider.select(
        (v) => (v.valueOrNull ?? [])
            .where((r) => recipeIdSet.contains(r.uuid))
            .map((r) => (
              calories: r.nutrition?.calories,
              protein: r.nutrition?.proteinContent,
              carbs: r.nutrition?.carbohydrateContent,
              fat: r.nutrition?.fatContent,
            ),)
            .toList(),
      ),
    );

    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int recipesWithNutrition = 0;

    for (final n in nutritionData) {
      final hasData = n.calories != null || n.fat != null || n.carbs != null || n.protein != null;
      if (hasData) {
        recipesWithNutrition++;
        if (n.calories != null) totalCalories += n.calories!;
        if (n.protein != null) totalProtein += n.protein!;
        if (n.carbs != null) totalCarbs += n.carbs!;
        if (n.fat != null) totalFat += n.fat!;
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