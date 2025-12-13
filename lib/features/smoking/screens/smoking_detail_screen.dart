import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

          return CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: recipe.imageUrl != null ? 250 : 120,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    recipe.name,
                    style: const TextStyle(
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  background: recipe.imageUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.outdoor_grill,
                                  size: 64,
                                  color: theme.colorScheme.outline,
                                ),
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
                          color: theme.colorScheme.primary,
                          child: const Icon(
                            Icons.outdoor_grill,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: recipe.isFavorite ? Colors.red : null,
                      shadows: recipe.imageUrl != null 
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
                      shadows: recipe.imageUrl != null 
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
                      shadows: recipe.imageUrl != null 
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
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert,
                      shadows: recipe.imageUrl != null 
                          ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                          : null,
                    ),
                  ),
                ],
              ),

              // Recipe details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick info cards
                      _buildQuickInfo(context, recipe),
                      
                      const SizedBox(height: 24),

                      // Seasonings section
                      if (recipe.seasonings.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Seasonings'),
                        const SizedBox(height: 12),
                        _buildSeasoningsList(context, recipe.seasonings),
                        const SizedBox(height: 24),
                      ],

                      // Directions section
                      if (recipe.directions.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Directions'),
                        const SizedBox(height: 12),
                        _buildDirectionsList(context, recipe.directions),
                        const SizedBox(height: 24),
                      ],

                      // Notes section
                      if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Notes'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recipe.notes!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickInfo(BuildContext context, SmokingRecipe recipe) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Temperature
        _buildInfoChip(
          context,
          Icons.thermostat,
          recipe.temperature,
          'Temperature',
        ),
        // Time
        _buildInfoChip(
          context,
          Icons.timer,
          recipe.time,
          'Time',
        ),
        // Wood
        _buildInfoChip(
          context,
          Icons.park,
          recipe.wood,
          'Wood',
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSeasoningsList(BuildContext context, List<SmokingSeasoning> seasonings) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: seasonings.asMap().entries.map((entry) {
          final index = entry.key;
          final seasoning = entry.value;
          final isLast = index == seasonings.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
            ),
            child: Row(
              children: [
                // Amount on left (if present)
                if (seasoning.amount != null && seasoning.amount!.isNotEmpty) ...[
                  SizedBox(
                    width: 80,
                    child: Text(
                      seasoning.amount!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                // Name
                Expanded(
                  child: Text(
                    seasoning.name,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
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
              backgroundColor: Theme.of(context).colorScheme.error,
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
