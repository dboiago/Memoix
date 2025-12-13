import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import 'modernist_edit_screen.dart';

/// Detail screen for viewing a modernist recipe - follows Mains pattern exactly
class ModernistDetailScreen extends ConsumerStatefulWidget {
  final int recipeId;

  const ModernistDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  ConsumerState<ModernistDetailScreen> createState() => _ModernistDetailScreenState();
}

class _ModernistDetailScreenState extends ConsumerState<ModernistDetailScreen> {
  final Set<int> _completedDirections = {};
  final Set<int> _checkedIngredients = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stepImagesKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipeAsync = ref.watch(modernistRecipeProvider(widget.recipeId));

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (recipe) {
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        return _buildDetailView(context, theme, recipe);
      },
    );
  }

  Widget _buildDetailView(BuildContext context, ThemeData theme, ModernistRecipe recipe) {
    // Use headerImage for the app bar, fall back to legacy imageUrl
    final headerImage = recipe.headerImage ?? recipe.imageUrl;
    final hasHeaderImage = headerImage != null && headerImage.isNotEmpty;
    final hasStepImages = recipe.stepImages.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with header image
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black87, offset: Offset(0, 1)),
                    Shadow(blurRadius: 16, color: Colors.black54),
                  ],
                ),
              ),
              background: hasHeaderImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildSingleImage(headerImage),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.3, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: theme.colorScheme.surfaceContainerHighest),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.primary : null,
                  shadows: hasHeaderImage
                      ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                      : null,
                ),
                onPressed: () {
                  ref.read(modernistRepositoryProvider).toggleFavorite(recipe.id);
                  ref.invalidate(modernistRecipeProvider(widget.recipeId));
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  shadows: hasHeaderImage
                      ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                      : null,
                ),
                tooltip: 'I made this',
                onPressed: () {
                  ref.read(modernistRepositoryProvider).incrementCookCount(recipe.id);
                  ref.invalidate(modernistRecipeProvider(widget.recipeId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged cook for ${recipe.name}!')),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, recipe),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_vert,
                  shadows: hasHeaderImage
                      ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                      : null,
                ),
              ),
            ],
          ),

          // Recipe metadata - chips like Mains
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags row (same style as Mains)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category chip (Concept/Technique)
                      Chip(
                        label: Text(recipe.type.displayName),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        visualDensity: VisualDensity.compact,
                      ),
                      // Technique category if set
                      if (recipe.technique != null && recipe.technique!.isNotEmpty)
                        Chip(
                          label: Text(recipe.technique!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.serves != null && recipe.serves!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.people, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.serves!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.time != null && recipe.time!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.time!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),

                  // Special Equipment (simple list style, no banner)
                  if (recipe.equipment.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Special Equipment',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: recipe.equipment.map((item) => Chip(
                        label: Text(item),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Ingredients and Directions - side by side like Mains
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useSideBySide = constraints.maxWidth > 600;

                if (useSideBySide) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ingredients on the left
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ingredients',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildIngredientsList(theme, recipe.ingredients),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Directions on the right
                        Expanded(
                          flex: 3,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Directions',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDirectionsList(theme, recipe),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Stacked layout for narrow screens
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Ingredients',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildIngredientsList(theme, recipe.ingredients),
                      const SizedBox(height: 24),
                      Text(
                        'Directions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDirectionsList(theme, recipe),
                    ],
                  ),
                );
              },
            ),
          ),

          // Step Images Gallery (under directions, before comments)
          if (hasStepImages)
            SliverToBoxAdapter(
              key: _stepImagesKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildStepImagesGallery(theme, recipe),
              ),
            ),

          // Comments section (at bottom, after recipe content) - matches Mains "Comments"
          if (recipe.notes != null && recipe.notes!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Comments',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(recipe.notes!),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(ThemeData theme, List<ModernistIngredient> ingredients) {
    if (ingredients.isEmpty) {
      return const Text(
        'No ingredients listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ingredient = entry.value;
        final isChecked = _checkedIngredients.contains(index);

        return InkWell(
          onTap: () {
            setState(() {
              if (isChecked) {
                _checkedIngredients.remove(index);
              } else {
                _checkedIngredients.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _checkedIngredients.add(index);
                        } else {
                          _checkedIngredients.remove(index);
                        }
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),

                // Ingredient name
                Text(
                  ingredient.name,
                  style: TextStyle(
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked
                        ? theme.colorScheme.onSurface.withOpacity(0.5)
                        : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Amount
                if (ingredient.displayText != ingredient.name) ...[
                  const SizedBox(width: 8),
                  Text(
                    ingredient.displayText.replaceFirst(ingredient.name, '').trim(),
                    style: TextStyle(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                // Notes
                Expanded(
                  child: ingredient.notes != null && ingredient.notes!.isNotEmpty
                      ? Text(
                          ingredient.notes!,
                          style: TextStyle(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.right,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDirectionsList(ThemeData theme, ModernistRecipe recipe) {
    final directions = recipe.directions;
    if (directions.isEmpty) {
      return const Text(
        'No directions listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: directions.asMap().entries.map((entry) {
        final index = entry.key;
        final direction = entry.value;
        final isCompleted = _completedDirections.contains(index);
        final hasImage = recipe.getStepImageIndex(index) != null;

        return InkWell(
          onTap: () => setState(() {
            if (isCompleted) {
              _completedDirections.remove(index);
            } else {
              _completedDirections.add(index);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.secondary.withOpacity(0.2)
                        : theme.colorScheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.secondary)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    direction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                // Image icon if step has an image
                if (hasImage)
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'View step image',
                    onPressed: () => _scrollToAndShowImage(recipe, index),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepImagesGallery(ThemeData theme, ModernistRecipe recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Step Images',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recipe.stepImages.length,
                itemBuilder: (context, imageIndex) {
                  // Find which step(s) use this image
                  final stepsUsingImage = <int>[];
                  for (int i = 0; i < recipe.directions.length; i++) {
                    if (recipe.getStepImageIndex(i) == imageIndex) {
                      stepsUsingImage.add(i + 1);
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(left: imageIndex == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => _showImageFullscreen(recipe.stepImages[imageIndex]),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(recipe.stepImages[imageIndex], width: 120, height: 120),
                          ),
                          // Step numbers badge
                          if (stepsUsingImage.isNotEmpty)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  stepsUsingImage.map((s) => 'Step $s').join(', '),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          // Expand icon
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, {double? width, double? height}) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    }
  }

  void _scrollToAndShowImage(ModernistRecipe recipe, int stepIndex) {
    final imageIndex = recipe.getStepImageIndex(stepIndex);
    if (imageIndex == null || imageIndex >= recipe.stepImages.length) return;

    // Scroll to the step images section
    final context = _stepImagesKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ).then((_) {
        // After scrolling, show the image fullscreen
        _showImageFullscreen(recipe.stepImages[imageIndex]);
      });
    } else {
      // If context not found, just show the image
      _showImageFullscreen(recipe.stepImages[imageIndex]);
    }
  }

  void _showImageFullscreen(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark background
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.black.withOpacity(0.9)),
            ),
            // Image
            Center(
              child: InteractiveViewer(
                child: imagePath.startsWith('http')
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleImage(String source) {
    final isLocal = !source.startsWith('http');
    return isLocal
        ? Image.file(File(source), fit: BoxFit.cover)
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
          );
  }

  void _handleMenuAction(String action, ModernistRecipe recipe) async {
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernistEditScreen(recipeId: recipe.id),
          ),
        );
        ref.invalidate(modernistRecipeProvider(widget.recipeId));
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Recipe'),
            content: Text('Are you sure you want to delete "${recipe.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.secondary,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await ref.read(modernistRepositoryProvider).delete(recipe.id);
          Navigator.pop(context);
        }
        break;
    }
  }
}
