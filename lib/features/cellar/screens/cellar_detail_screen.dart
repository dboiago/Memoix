import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../shared/widgets/memoix_header.dart';
import '../../settings/screens/settings_screen.dart';
import '../../sharing/services/share_service.dart';
import '../../recipes/models/cuisine.dart';
import '../models/cellar_entry.dart';
import '../repository/cellar_repository.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/widgets/memoix_snackbar.dart';

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
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final theme = Theme.of(context);
    final hasHeaderImage = showHeaderImages && entry.imageUrl != null && entry.imageUrl!.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          MemoixHeader(
            title: entry.name,
            headerImage: showHeaderImages ? entry.imageUrl : null,
            isFavorite: entry.isFavorite,
            onFavoritePressed: () async {
              await ref.read(cellarRepositoryProvider).toggleFavorite(entry);
              ref.invalidate(allCellarEntriesProvider);
              await processIntegrityResponses(ref);
            },
            onSharePressed: () => _shareEntry(context, ref),
            onEditPressed: () => AppRoutes.toCellarEdit(context, entryId: entry.uuid),
            onDuplicatePressed: () => _duplicateEntry(context, ref),
            onDeletePressed: () => _confirmDelete(context, ref),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Metadata chips
                _buildChipMetadata(theme),
                const SizedBox(height: 16),
                // Tasting notes section (always shown, with placeholder if empty)
                Card(
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipMetadata(ThemeData theme) {
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
        label: Text(_capitalize(entry.category!)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
        visualDensity: VisualDensity.compact,
      ));
    }

    // Producer (use 2-letter country code in ALL CAPS - e.g., "ZA" not "Za")
    if (entry.producer != null && entry.producer!.isNotEmpty) {
      final cuisine = Cuisine.byCode(entry.producer!);
      final displayCode = cuisine != null ? cuisine.code : entry.producer!.toUpperCase();
      chips.add(Chip(
        label: Text(displayCode),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
        MemoixSnackBar.show('${entry.name} deleted');
      }
    }
  }

  void _duplicateEntry(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(cellarRepositoryProvider);
    final newEntry = CellarEntry()
      ..uuid = ''  // Will be generated on save
      ..name = '${entry.name} (Copy)'
      ..category = entry.category
      ..producer = entry.producer
      ..tastingNotes = entry.tastingNotes
      ..abv = entry.abv
      ..ageVintage = entry.ageVintage
      ..buy = entry.buy
      ..priceRange = entry.priceRange
      ..imageUrl = entry.imageUrl
      ..source = CellarSource.personal
      ..isFavorite = false;
    
    await repo.saveEntry(newEntry);
    MemoixSnackBar.show('Created copy: ${newEntry.name}');
  }

  void _shareEntry(BuildContext context, WidgetRef ref) {
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
                'Share "${entry.name}"',
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
                shareService.showCellarQrCode(context, entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareCellarEntry(entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyCellarShareLink(entry);
                MemoixSnackBar.show('Link copied to clipboard');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
