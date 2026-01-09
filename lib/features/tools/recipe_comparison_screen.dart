import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/routes/router.dart';
import '../../core/widgets/memoix_snackbar.dart';
import '../recipes/models/recipe.dart';
import '../notes/models/scratch_pad.dart';
import '../notes/repository/scratch_pad_repository.dart';
import 'recipe_comparison_provider.dart';

/// Recipe Comparison screen for side-by-side recipe comparison
/// 
/// Allows users to:
/// - Compare two recipes from any source (DB, URL, OCR)
/// - Select ingredients and steps from both recipes
/// - Send selections to Scratch Pad as a structured draft
class RecipeComparisonScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled recipe for slot 1
  final Recipe? prefilledRecipe;

  const RecipeComparisonScreen({
    super.key,
    this.prefilledRecipe,
  });

  @override
  ConsumerState<RecipeComparisonScreen> createState() => _RecipeComparisonScreenState();
}

class _RecipeComparisonScreenState extends ConsumerState<RecipeComparisonScreen> {
  @override
  void initState() {
    super.initState();
    // Set prefilled recipe if provided
    if (widget.prefilledRecipe != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(recipeComparisonProvider.notifier).setRecipe1(widget.prefilledRecipe!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comparison = ref.watch(recipeComparisonProvider);
    final hasSelection = comparison.selectedIngredients1.isNotEmpty ||
        comparison.selectedIngredients2.isNotEmpty ||
        comparison.selectedSteps1.isNotEmpty ||
        comparison.selectedSteps2.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Recipes'),
        actions: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'Send to Scratch Pad',
              onPressed: () => _sendToScratchPad(context, ref, comparison),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate split view height (similar to recipe detail pattern)
          final isMobile = constraints.maxWidth < 600;
          final baseHeightRatio = isMobile ? 0.70 : 0.80;
          final splitViewHeight = (constraints.maxHeight * baseHeightRatio).clamp(
            isMobile ? 300.0 : 400.0,
            isMobile ? 550.0 : 700.0,
          );

          return Column(
            children: [
              // Side-by-side comparison view
              SizedBox(
                height: splitViewHeight,
                child: Row(
                  children: [
                    // Recipe Slot 1
                    Expanded(
                      child: _RecipeSlot(
                        slotNumber: 1,
                        recipe: comparison.recipe1,
                        selectedIngredients: comparison.selectedIngredients1,
                        selectedSteps: comparison.selectedSteps1,
                        onIngredientTap: (index) {
                          ref.read(recipeComparisonProvider.notifier).toggleIngredient1(index);
                        },
                        onStepTap: (index) {
                          ref.read(recipeComparisonProvider.notifier).toggleStep1(index);
                        },
                        onSelectRecipe: () => _selectRecipeForSlot(context, ref, 1),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    // Recipe Slot 2
                    Expanded(
                      child: _RecipeSlot(
                        slotNumber: 2,
                        recipe: comparison.recipe2,
                        selectedIngredients: comparison.selectedIngredients2,
                        selectedSteps: comparison.selectedSteps2,
                        onIngredientTap: (index) {
                          ref.read(recipeComparisonProvider.notifier).toggleIngredient2(index);
                        },
                        onStepTap: (index) {
                          ref.read(recipeComparisonProvider.notifier).toggleStep2(index);
                        },
                        onSelectRecipe: () => _selectRecipeForSlot(context, ref, 2),
                      ),
                    ),
                  ],
                ),
              ),
              // Info footer
              if (hasSelection)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap ingredients or steps to select. Selected items will be sent to Scratch Pad.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Show selection modal for choosing a recipe source
  Future<void> _selectRecipeForSlot(BuildContext context, WidgetRef ref, int slot) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Select from Library'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan Text (OCR)'),
              onTap: () => Navigator.pop(context, 'ocr'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    switch (selected) {
      case 'library':
        // TODO: Open recipe picker
        MemoixSnackBar.show('Recipe picker coming soon');
        break;
      case 'url':
        AppRoutes.toURLImport(context);
        break;
      case 'ocr':
        AppRoutes.toOCRScanner(context);
        break;
    }
  }

  /// Send selected items to Scratch Pad
  Future<void> _sendToScratchPad(
    BuildContext context,
    WidgetRef ref,
    RecipeComparisonState comparison,
  ) async {
    // Collect all selected ingredients
    final ingredients = <Ingredient>[];
    for (final index in comparison.selectedIngredients1) {
      if (index < comparison.recipe1!.ingredients.length) {
        ingredients.add(comparison.recipe1!.ingredients[index]);
      }
    }
    for (final index in comparison.selectedIngredients2) {
      if (index < comparison.recipe2!.ingredients.length) {
        ingredients.add(comparison.recipe2!.ingredients[index]);
      }
    }

    // Collect all selected steps
    final steps = <String>[];
    for (final index in comparison.selectedSteps1) {
      if (index < comparison.recipe1!.directions.length) {
        steps.add(comparison.recipe1!.directions[index]);
      }
    }
    for (final index in comparison.selectedSteps2) {
      if (index < comparison.recipe2!.directions.length) {
        steps.add(comparison.recipe2!.directions[index]);
      }
    }

    if (ingredients.isEmpty && steps.isEmpty) {
      MemoixSnackBar.show('No items selected');
      return;
    }

    // Create a structured draft
    final draft = RecipeDraft()
      ..uuid = const Uuid().v4()
      ..name = 'Compared Recipe Draft'
      ..ingredients = ingredients.map((i) => '${i.quantity} ${i.unit} ${i.name}'.trim()).join('\n')
      ..directions = steps.join('\n\n')
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await ref.read(scratchPadRepositoryProvider).saveDraft(draft);

    if (mounted) {
      MemoixSnackBar.showSuccess('Sent to Scratch Pad');
      // Navigate to Scratch Pad
      AppRoutes.toScratchPad(context);
    }
  }
}

/// Widget for a single recipe slot
class _RecipeSlot extends StatelessWidget {
  final int slotNumber;
  final Recipe? recipe;
  final Set<int> selectedIngredients;
  final Set<int> selectedSteps;
  final void Function(int index) onIngredientTap;
  final void Function(int index) onStepTap;
  final VoidCallback onSelectRecipe;

  const _RecipeSlot({
    required this.slotNumber,
    required this.recipe,
    required this.selectedIngredients,
    required this.selectedSteps,
    required this.onIngredientTap,
    required this.onStepTap,
    required this.onSelectRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (recipe == null) {
      // Empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Recipe $slotNumber',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSelectRecipe,
              icon: const Icon(Icons.add),
              label: const Text('Select Recipe'),
            ),
          ],
        ),
      );
    }

    // Recipe loaded
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recipe title
        Row(
          children: [
            Expanded(
              child: Text(
                recipe!.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              iconSize: 20,
              tooltip: 'Change recipe',
              onPressed: onSelectRecipe,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ingredients section
        Text(
          'Ingredients',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(recipe!.ingredients.length, (index) {
          final ingredient = recipe!.ingredients[index];
          final isSelected = selectedIngredients.contains(index);
          return _SelectableItem(
            isSelected: isSelected,
            onTap: () => onIngredientTap(index),
            child: Text(
              '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}'.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          );
        }),

        const SizedBox(height: 24),

        // Steps section
        Text(
          'Steps',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(recipe!.directions.length, (index) {
          final step = recipe!.directions[index];
          final isSelected = selectedSteps.contains(index);
          return _SelectableItem(
            isSelected: isSelected,
            onTap: () => onStepTap(index),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Selectable list item with visual feedback
class _SelectableItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableItem({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
