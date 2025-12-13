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
    final allImages = recipe.getAllImages();
    final hasImage = allImages.isNotEmpty;
    final hasMultipleImages = allImages.length > 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image (matches Mains)
          SliverAppBar(
            expandedHeight: hasImage ? 250 : 150,
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
              background: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        hasMultipleImages
                            ? _buildImageCarousel(allImages)
                            : _buildSingleImage(allImages.first),
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
                  shadows: hasImage
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
                  shadows: hasImage
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
                  shadows: hasImage
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
                                  _buildDirectionsList(theme, recipe.directions),
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
                      _buildDirectionsList(theme, recipe.directions),
                    ],
                  ),
                );
              },
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

  Widget _buildDirectionsList(ThemeData theme, List<String> directions) {
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
              ],
            ),
          ),
        );
      }).toList(),
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

  Widget _buildImageCarousel(List<String> images) {
    return _ImageCarousel(images: images);
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

/// Simple carousel widget for recipe images
class _ImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final source = widget.images[index];
            final isLocalFile = !source.startsWith('http');
            return isLocalFile
                ? Image.file(
                    File(source),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                  )
                : Image.network(
                    source,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
                  );
          },
        ),

        // Page indicator badge (top right)
        Positioned(
          top: 48,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPage + 1}/${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Page indicators (bottom)
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == _currentPage
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
