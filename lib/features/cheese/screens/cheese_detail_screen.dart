import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../settings/screens/settings_screen.dart';
import '../../recipes/models/cuisine.dart';
import '../models/cheese_entry.dart';
import '../repository/cheese_repository.dart';

/// Cheese detail screen - displays cheese entry info
class CheeseDetailScreen extends ConsumerWidget {
  final String entryId;

  const CheeseDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allCheeseEntriesProvider);

    return entriesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (entries) {
        final entry = entries.firstWhere(
          (e) => e.uuid == entryId,
          orElse: () => CheeseEntry()..name = '',
        );

        if (entry.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Entry not found')),
          );
        }

        return _CheeseDetailView(entry: entry);
      },
    );
  }
}

class _CheeseDetailView extends ConsumerWidget {
  final CheeseEntry entry;

  const _CheeseDetailView({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasHeaderImage = showHeaderImages && entry.imageUrl != null && entry.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 16,
                end: 160,
              ),
              background: hasHeaderImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildHeaderBackground(theme),
                        // Gradient scrim for legibility
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black54,
                              ],
                              stops: [0.5, 1.0],
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
                  entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: entry.isFavorite ? theme.colorScheme.secondary : null,
                ),
                onPressed: () async {
                  await ref.read(cheeseRepositoryProvider).toggleFavorite(entry);
                  ref.invalidate(allCheeseEntriesProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),

          // Metadata chips (only show populated fields)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMetadataChips(theme),
            ),
          ),

          // Flavour notes section (always shown, with placeholder if empty)
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
                        'Flavour',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entry.flavour != null && entry.flavour!.isNotEmpty)
                        Text(
                          entry.flavour!,
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'No flavour notes added.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
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
      ),
    );
  }

  Widget _buildMetadataChips(ThemeData theme) {
    final chips = <Widget>[];

    // Buy status
    if (entry.buy) {
      chips.add(Chip(
        label: const Text('Buy'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Country (use adjective form like "French" not "France")
    if (entry.country != null && entry.country!.isNotEmpty) {
      chips.add(Chip(
        label: Text(Cuisine.toAdjective(entry.country!)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Milk
    if (entry.milk != null && entry.milk!.isNotEmpty) {
      chips.add(Chip(
        label: Text(_capitalize(entry.milk!)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Texture
    if (entry.texture != null && entry.texture!.isNotEmpty) {
      chips.add(Chip(
        label: Text(_capitalize(entry.texture!)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Type
    if (entry.type != null && entry.type!.isNotEmpty) {
      chips.add(Chip(
        label: Text(_capitalize(entry.type!)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Price range (displayed as dollar signs)
    if (entry.priceRange != null && entry.priceRange! > 0) {
      final priceDisplay = '\$' * entry.priceRange!;
      chips.add(Chip(
        label: Text(priceDisplay),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    if (entry.imageUrl == null || entry.imageUrl!.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
      );
    }

    if (entry.imageUrl!.startsWith('http://') || entry.imageUrl!.startsWith('https://')) {
      return Image.network(
        entry.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    } else {
      return Image.file(
        File(entry.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'edit':
        AppRoutes.toCheeseEdit(context, entryId: entry.uuid);
        break;
      case 'duplicate':
        _duplicateEntry(context, ref);
        break;
      case 'delete':
        final theme = Theme.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: Text('Are you sure you want to delete "${entry.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(cheeseRepositoryProvider).deleteEntry(entry.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${entry.name} deleted')),
            );
          }
        }
        break;
    }
  }

  void _duplicateEntry(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(cheeseRepositoryProvider);
    final newEntry = CheeseEntry()
      ..uuid = ''  // Will be generated on save
      ..name = '${entry.name} (Copy)'
      ..country = entry.country
      ..milk = entry.milk
      ..texture = entry.texture
      ..type = entry.type
      ..flavour = entry.flavour
      ..buy = entry.buy
      ..priceRange = entry.priceRange
      ..imageUrl = entry.imageUrl
      ..source = CheeseSource.personal
      ..isFavorite = false;
    
    await repo.saveEntry(newEntry);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${newEntry.name}')),
      );
    }
  }

  /// Capitalizes the first letter of each word
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
