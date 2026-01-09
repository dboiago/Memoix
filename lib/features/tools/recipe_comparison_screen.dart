import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/routes/router.dart';
import '../../core/widgets/memoix_snackbar.dart';
import '../../shared/widgets/recipe_picker_modal.dart';
import '../recipes/models/recipe.dart';
import '../notes/models/scratch_pad.dart';
import '../notes/repository/scratch_pad_repository.dart';
import 'recipe_comparison_provider.dart';

/// Global RouteObserver to track when comparison screen becomes inactive
/// Exported for registration in MaterialApp
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// Recipe Comparison screen for side-by-side recipe comparison
/// 
/// Allows users to:
/// - Compare two recipes from any source (DB, URL, OCR)
/// - Select ingredients and steps from both recipes
/// - Send selections to Scratch Pad as a structured draft
class RecipeComparisonScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled recipe for slot 1 or 2
  final Recipe? prefilledRecipe;
  
  /// Which slot to fill with prefilledRecipe (1 or 2)
  final int targetSlot;

  const RecipeComparisonScreen({
    super.key,
    this.prefilledRecipe,
    this.targetSlot = 1,
  });

  @override
  ConsumerState<RecipeComparisonScreen> createState() => _RecipeComparisonScreenState();
}

class _RecipeComparisonScreenState extends ConsumerState<RecipeComparisonScreen> with WidgetsBindingObserver, RouteAware {
  final _draftTitleController = TextEditingController(text: 'Compared Recipe Draft');
  
  // Track if this screen is currently visible
  bool _isActive = true;

@override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Run this after the first frame to ensure safe provider access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. ALWAYS reset the state when entering this screen.
      // This fixes the "sloppy" behavior where old data persists if the 
      // previous screen instance wasn't fully disposed.
      ref.read(recipeComparisonProvider.notifier).reset();

      // 2. If we have a prefilled recipe (e.g. from Detail Screen), apply it NOW.
      // This runs immediately after the reset, so the user sees the correct state.
      if (widget.prefilledRecipe != null) {
        if (widget.targetSlot == 2) {
          ref.read(recipeComparisonProvider.notifier).setRecipe2(widget.prefilledRecipe!);
        } else {
          ref.read(recipeComparisonProvider.notifier).setRecipe1(widget.prefilledRecipe!);
        }
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _draftTitleController.dispose();
    // Reset comparison state when screen is disposed
    ref.read(recipeComparisonProvider.notifier).reset();
    super.dispose();
  }
  
  // RouteAware methods - called when route visibility changes
  @override
    void didPushNext() {
      // Another route was pushed on top of this one (e.g. Import Screen).
      _isActive = false;
      
      // EXPLANATION: If we reset here, we lose the 'pendingImportSlot' 
      // we just set before navigating to the import screen.
    }
  
  @override
  void didPopNext() {
    // The route that was on top was popped, this route is now visible again
    _isActive = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
      // We do NOT want to lose our work just because we switched apps!
      /* if (state == AppLifecycleState.paused) {
        ref.read(recipeComparisonProvider.notifier).reset();
      }
      */
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
          TextButton.icon(
            // Disable the button if nothing is selected, instead of hiding it
            onPressed: hasSelection 
                ? () => _sendToScratchPad(context, ref, comparison)
                : null,
            icon: const Icon(Icons.send),
            label: const Text('Send to Draft'),
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
              title: const Text('Saved Recipes'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('URL Import'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('OCR Import'),
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
        final recipe = await showModalBottomSheet<Recipe>(
          context: context,
          isScrollControlled: true,
          builder: (context) => const RecipePickerModal(
            title: 'Select Recipe',
          ),
        );
        
        if (recipe != null && mounted) {
          if (slot == 1) {
            ref.read(recipeComparisonProvider.notifier).setRecipe1(recipe);
          } else {
            ref.read(recipeComparisonProvider.notifier).setRecipe2(recipe);
          }
        }
        break;
      case 'url':
        ref.read(recipeComparisonProvider.notifier).setPendingImportSlot(slot);
        AppRoutes.toURLImport(context);
        break;
      case 'ocr':
        ref.read(recipeComparisonProvider.notifier).setPendingImportSlot(slot);
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
    // Collect all selected ingredients with their preparation notes
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

    // Collect all selected steps with their images
    final steps = <String>[];
    final stepImages = <String>[];
    final stepImageMap = <String>[];
    
    var stepCounter = 0;
    
    // Recipe 1 steps
    for (final index in comparison.selectedSteps1) {
      if (index < comparison.recipe1!.directions.length) {
        steps.add(comparison.recipe1!.directions[index]);
        
        // Find images for this step
        final imagesForStep = <String>[];
        for (var i = 0; i < comparison.recipe1!.stepImageMap.length; i++) {
          final parts = comparison.recipe1!.stepImageMap[i].split(':');
          if (parts.length == 2 && int.parse(parts[0]) == index) {
            final imageIndex = int.parse(parts[1]);
            if (imageIndex < comparison.recipe1!.stepImages.length) {
              imagesForStep.add(comparison.recipe1!.stepImages[imageIndex]);
            }
          }
        }
        
        // Add images to draft
        for (final image in imagesForStep) {
          stepImages.add(image);
          stepImageMap.add('$stepCounter:${stepImages.length - 1}');
        }
        
        stepCounter++;
      }
    }
    
    // Recipe 2 steps
    for (final index in comparison.selectedSteps2) {
      if (index < comparison.recipe2!.directions.length) {
        steps.add(comparison.recipe2!.directions[index]);
        
        // Find images for this step
        final imagesForStep = <String>[];
        for (var i = 0; i < comparison.recipe2!.stepImageMap.length; i++) {
          final parts = comparison.recipe2!.stepImageMap[i].split(':');
          if (parts.length == 2 && int.parse(parts[0]) == index) {
            final imageIndex = int.parse(parts[1]);
            if (imageIndex < comparison.recipe2!.stepImages.length) {
              imagesForStep.add(comparison.recipe2!.stepImages[imageIndex]);
            }
          }
        }
        
        // Add images to draft
        for (final image in imagesForStep) {
          stepImages.add(image);
          stepImageMap.add('$stepCounter:${stepImages.length - 1}');
        }
        
        stepCounter++;
      }
    }

    if (ingredients.isEmpty && steps.isEmpty) {
      MemoixSnackBar.show('No items selected');
      return;
    }

    // Show dialog to confirm title
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draft Title'),
        content: TextField(
          controller: _draftTitleController,
          decoration: const InputDecoration(
            labelText: 'Recipe Name',
            hintText: 'Enter a name for this draft',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send to Draft'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final titleChanged = _draftTitleController.text.trim() != 'Compared Recipe Draft' &&
                        _draftTitleController.text.trim().isNotEmpty;
    
    // Determine if we should create new draft or update existing
    final String draftUuid;
    if (comparison.currentDraftUuid != null && !titleChanged) {
      // Reuse existing draft UUID if title hasn't changed
      draftUuid = comparison.currentDraftUuid!;
    } else {
      // Create new UUID if title changed or first time
      draftUuid = const Uuid().v4();
      ref.read(recipeComparisonProvider.notifier).setCurrentDraftUuid(draftUuid);
    }

    // Convert Ingredients to DraftIngredients (structured format with preparation notes)
    final draftIngredients = ingredients.map((i) => DraftIngredient(
      name: i.name,
      quantity: i.amount,
      unit: i.unit,
      preparation: i.preparation,
    )).toList();

    // Create or update draft using structured format
    final draft = RecipeDraft()
      ..uuid = draftUuid
      ..name = _draftTitleController.text.trim().isEmpty 
          ? 'Compared Recipe Draft' 
          : _draftTitleController.text.trim()
      ..structuredIngredients = draftIngredients
      ..structuredDirections = steps
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await ref.read(scratchPadRepositoryProvider).updateDraft(draft);

    if (mounted) {
      // Invalidate the drafts provider to ensure the new draft is available
      ref.invalidate(recipeDraftsProvider);
      
      // Navigate immediately to the draft editor
      AppRoutes.toScratchPad(context, draftUuid: draftUuid);
      
      // Show success message
      MemoixSnackBar.showSaved(
        itemName: draft.name,
        actionLabel: 'View',
        onView: () {
          // Already navigated, this is just for consistency
        },
      );
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
          
          return _SelectableIngredient(
            isSelected: isSelected,
            onTap: () => onIngredientTap(index),
            ingredient: ingredient,
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
          
          // Find associated image for this step
          String? stepImagePath;
          for (final mapping in recipe!.stepImageMap) {
            final parts = mapping.split(':');
            if (parts.length == 2 && int.tryParse(parts[0]) == index) {
              final imageIndex = int.tryParse(parts[1]);
              if (imageIndex != null && imageIndex < recipe!.stepImages.length) {
                stepImagePath = recipe!.stepImages[imageIndex];
              }
            }
          }
          
          return _SelectableStep(
            isSelected: isSelected,
            onTap: () => onStepTap(index),
            stepNumber: index + 1,
            stepText: step,
            imagePath: stepImagePath,
          );
        }),
      ],
    );
  }
}

/// Selectable ingredient item with linked preparation bubble
class _SelectableIngredient extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Ingredient ingredient;

  const _SelectableIngredient({
    required this.isSelected,
    required this.onTap,
    required this.ingredient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrep = ingredient.preparation != null && ingredient.preparation!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.secondary
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ingredient.amount ?? ''} ${ingredient.unit ?? ''} ${ingredient.name}'.trim(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (hasPrep) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ingredient.preparation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable step item with optional image
class _SelectableStep extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final int stepNumber;
  final String stepText;
  final String? imagePath;

  const _SelectableStep({
    required this.isSelected,
    required this.onTap,
    required this.stepNumber,
    required this.stepText,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imagePath != null && imagePath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.secondary
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkmark on left (like ingredients)
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stepText,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (hasImage) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imagePath!.startsWith('http://') || imagePath!.startsWith('https://')
                            ? Image.network(
                                imagePath!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              )
                            : Image.file(
                                File(imagePath!),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.secondary
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
                    ? theme.colorScheme.secondary
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
