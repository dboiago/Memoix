import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../models/cellar_entry.dart';
import '../repository/cellar_repository.dart';

/// Cellar detail screen - displays cellar entry info
class CellarDetailScreen extends ConsumerWidget {
  final String entryId;

  const CellarDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allCellarEntriesProvider);

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
          orElse: () => CellarEntry()..name = '',
        );

        if (entry.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Entry not found')),
          );
        }

        return _CellarDetailView(entry: entry);
      },
    );
  }
}

class _CellarDetailView extends ConsumerWidget {
  final CellarEntry entry;

  const _CellarDetailView({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasImage = entry.imageUrl != null && entry.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasImage ? 250 : 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                entry.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black87, offset: Offset(0, 1)),
                    Shadow(blurRadius: 16, color: Colors.black54),
                  ],
                ),
              ),
              background: _buildHeaderBackground(theme),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: entry.isFavorite ? Colors.red : null,
                  shadows: hasImage 
                      ? [const Shadow(blurRadius: 8, color: Colors.black54)]
                      : null,
                ),
                onPressed: () {
                  ref.read(cellarRepositoryProvider).toggleFavorite(entry);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
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

          // Metadata chips (only show populated fields)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMetadataChips(theme),
            ),
          ),

          // Tasting notes section (always shown, with placeholder if empty)
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
                        'Tasting Notes',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entry.tastingNotes != null && entry.tastingNotes!.isNotEmpty)
                        Text(
                          entry.tastingNotes!,
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'No tasting notes added.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.outline,
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

    // Category
    if (entry.category != null && entry.category!.isNotEmpty) {
      chips.add(Chip(
        label: Text(entry.category!),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Producer
    if (entry.producer != null && entry.producer!.isNotEmpty) {
      chips.add(Chip(
        label: Text(entry.producer!),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // ABV (with % suffix, sanitized)
    if (entry.abv != null && entry.abv!.isNotEmpty) {
      final abvValue = entry.abv!.replaceAll('%', '').trim();
      if (abvValue.isNotEmpty) {
        chips.add(Chip(
          label: Text('$abvValue%'),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
          visualDensity: VisualDensity.compact,
        ));
      }
    }

    // Age/Vintage (optional)
    if (entry.ageVintage != null && entry.ageVintage!.isNotEmpty) {
      chips.add(Chip(
        label: Text(entry.ageVintage!),
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
        AppRoutes.toCellarEdit(context, entryId: entry.uuid);
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
          await ref.read(cellarRepositoryProvider).deleteEntry(entry.id);
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
}
