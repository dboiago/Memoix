import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';
import '../../sharing/services/share_service.dart';
import 'smoking_edit_screen.dart';

/// Detail screen showing a smoking recipe's full information
class SmokingDetailScreen extends ConsumerWidget {
  final String recipeId;

  const SmokingDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipeAsync = ref.watch(smokingRecipeByUuidProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recipe) {
          if (recipe == null) {
            return const Center(child: Text('Recipe not found'));
          }

          final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;

          return CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: hasImage ? 250 : 120,
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
                            Image.network(
                              recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            // Gradient overlay for title readability
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: recipe.isFavorite ? Colors.red : null,
                      shadows: hasImage 
                          ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                          : null,
                    ),
                    onPressed: () {
                      ref.read(smokingRepositoryProvider).toggleFavorite(recipe.uuid);
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
                    onPressed: () async {
                      await ref.read(smokingRepositoryProvider).incrementCookCount(recipe.uuid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Logged cook for ${recipe.name}!'),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      shadows: hasImage 
                          ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                          : null,
                    ),
                    onPressed: () => _shareRecipe(context, ref, recipe),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editRecipe(context, recipe);
                          break;
                        case 'delete':
                          _confirmDelete(context, ref, recipe);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
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

              // Recipe details - styled like regular recipe page
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick info chips (category, temperature, time, wood)
                      _buildQuickInfo(context, recipe),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Ingredients Card (main item + seasonings)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ingredients header
                          Text(
                            'Ingredients',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Main item section
                          if (recipe.item != null && recipe.item!.isNotEmpty) ...[
                            _buildIngredientSection(
                              theme,
                              'Main',
                              [recipe.item!],
                            ),
                          ],
                          
                          // Seasonings section
                          if (recipe.seasonings.isNotEmpty) ...[
                            if (recipe.item != null && recipe.item!.isNotEmpty)
                              const SizedBox(height: 16),
                            _buildIngredientSection(
                              theme,
                              recipe.seasonings.length == 1 ? 'Seasoning' : 'Seasonings',
                              recipe.seasonings.map((s) => s.displayText).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Directions Card
              if (recipe.directions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                            _buildDirectionsList(context, recipe.directions),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Notes section (if present)
              if (recipe.notes != null && recipe.notes!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              recipe.notes!,
                              style: theme.textTheme.bodyMedium,
                            ),
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
          );
        },
      ),
    );
  }
  
  /// Build an ingredient section with header and checkable list
  Widget _buildIngredientSection(ThemeData theme, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        // Ingredient list
        _SmokingIngredientList(items: items),
      ],
    );
  }

  Widget _buildQuickInfo(BuildContext context, SmokingRecipe recipe) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Category with colored dot (not item)
        if (recipe.category != null)
          Chip(
            avatar: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: MemoixColors.forSmokedItemDot(recipe.category),
                shape: BoxShape.circle,
              ),
            ),
            label: Text(recipe.category!),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface),
            visualDensity: VisualDensity.compact,
          ),
        // Temperature
        Chip(
          avatar: Icon(Icons.thermostat, size: 16, color: theme.colorScheme.onSurface),
          label: Text(recipe.temperature),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
          visualDensity: VisualDensity.compact,
        ),
        // Time
        Chip(
          avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
          label: Text(recipe.time),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
          visualDensity: VisualDensity.compact,
        ),
        // Wood
        Chip(
          avatar: Icon(Icons.park, size: 16, color: theme.colorScheme.onSurface),
          label: Text(recipe.wood),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildDirectionsList(BuildContext context, List<String> directions) {
    final theme = Theme.of(context);

    return Column(
      children: directions.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number with outlined secondary styling
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    step,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _editRecipe(BuildContext context, SmokingRecipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmokingEditScreen(recipeId: recipe.uuid),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SmokingRecipe recipe,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(smokingRepositoryProvider).deleteRecipe(recipe.uuid);
      Navigator.pop(context);
    }
  }

  void _shareRecipe(BuildContext context, WidgetRef ref, SmokingRecipe recipe) {
    final shareService = ref.read(shareServiceProvider);
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Share "${recipe.name}"',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.qr_code, color: theme.colorScheme.primary),
              title: const Text('Show QR Code'),
              subtitle: const Text('Others can scan to import'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.showSmokingQrCode(context, recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareSmokingRecipe(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copySmokingShareLink(recipe);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard!')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.text_snippet, color: theme.colorScheme.primary),
              title: const Text('Share as Text'),
              subtitle: const Text('Full recipe in plain text'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareSmokingAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Stateful ingredient list with checkboxes for smoking recipes
class _SmokingIngredientList extends StatefulWidget {
  final List<String> items;

  const _SmokingIngredientList({required this.items});

  @override
  State<_SmokingIngredientList> createState() => _SmokingIngredientListState();
}

class _SmokingIngredientListState extends State<_SmokingIngredientList> {
  final Set<int> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isChecked = _checkedItems.contains(index);

        return InkWell(
          onTap: () {
            setState(() {
              if (isChecked) {
                _checkedItems.remove(index);
              } else {
                _checkedItems.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _checkedItems.add(index);
                        } else {
                          _checkedItems.remove(index);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : null,
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
}
