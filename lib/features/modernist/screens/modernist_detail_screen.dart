import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/colors.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import 'modernist_edit_screen.dart';

/// Detail screen for viewing a modernist recipe
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
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
                        _buildImage(allImages.first),
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
                  : Container(color: MemoixColors.molecular.withOpacity(0.3)),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.primary : null,
                ),
                onPressed: () {
                  ref.read(modernistRepositoryProvider).toggleFavorite(recipe.id);
                  ref.invalidate(modernistRecipeProvider(widget.recipeId));
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, recipe),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Type and technique badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TypeBadge(type: recipe.type),
                    if (recipe.technique != null && recipe.technique!.isNotEmpty)
                      _TechniqueBadge(technique: recipe.technique!),
                  ],
                ),
                const SizedBox(height: 16),

                // Metadata row
                Row(
                  children: [
                    if (recipe.serves != null && recipe.serves!.isNotEmpty) ...[
                      Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(recipe.serves!, style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                    ],
                    if (recipe.time != null && recipe.time!.isNotEmpty) ...[
                      Icon(Icons.schedule, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(recipe.time!, style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                    ],
                    if (recipe.difficulty != null && recipe.difficulty!.isNotEmpty) ...[
                      Icon(Icons.trending_up, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(recipe.difficulty!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),

                // Equipment section (shown first, before ingredients)
                if (recipe.equipment.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildEquipmentSection(theme, recipe.equipment),
                ],

                // Ingredients section
                if (recipe.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildIngredientsSection(theme, recipe.ingredients),
                ],

                // Directions section
                if (recipe.directions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildDirectionsSection(theme, recipe.directions),
                ],

                // Science notes
                if (recipe.scienceNotes != null && recipe.scienceNotes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildScienceNotesSection(theme, recipe.scienceNotes!),
                ],

                // Notes
                if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildNotesSection(theme, recipe.notes!),
                ],

                // Source URL
                if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSourceSection(theme, recipe.sourceUrl!),
                ],

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(modernistRepositoryProvider).incrementCookCount(recipe.id);
          ref.invalidate(modernistRecipeProvider(widget.recipeId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as made!')),
          );
        },
        backgroundColor: MemoixColors.molecular,
        icon: const Icon(Icons.check),
        label: const Text('I Made This'),
      ),
    );
  }

  Widget _buildImage(String source) {
    final isLocal = !source.startsWith('http');
    return isLocal
        ? Image.file(File(source), fit: BoxFit.cover)
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: MemoixColors.molecular.withOpacity(0.3),
            ),
          );
  }

  Widget _buildEquipmentSection(ThemeData theme, List<String> equipment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build_outlined, size: 20, color: MemoixColors.molecular),
            const SizedBox(width: 8),
            Text(
              'Special Equipment',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MemoixColors.molecular.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MemoixColors.molecular.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: equipment.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: MemoixColors.molecular),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(ThemeData theme, List<ModernistIngredient> ingredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...ingredients.map((ingredient) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.displayText,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (ingredient.notes != null && ingredient.notes!.isNotEmpty)
                      Text(
                        ingredient.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildDirectionsSection(ThemeData theme, List<String> directions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Directions',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...directions.asMap().entries.map((entry) {
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
        }),
      ],
    );
  }

  Widget _buildScienceNotesSection(ThemeData theme, String scienceNotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.science, size: 20, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'The Science',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(scienceNotes, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme, String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Notes',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(notes, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildSourceSection(ThemeData theme, String sourceUrl) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(sourceUrl)),
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sourceUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

class _TypeBadge extends StatelessWidget {
  final ModernistType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == ModernistType.technique ? Colors.purple : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TechniqueBadge extends StatelessWidget {
  final String technique;

  const _TechniqueBadge({required this.technique});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MemoixColors.molecular.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MemoixColors.molecular.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science, size: 16, color: MemoixColors.molecular),
          const SizedBox(width: 4),
          Text(
            technique,
            style: TextStyle(color: MemoixColors.molecular, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
