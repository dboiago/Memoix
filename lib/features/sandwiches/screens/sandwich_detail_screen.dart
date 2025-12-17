import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../models/sandwich.dart';
import '../repository/sandwich_repository.dart';
import '../../sharing/services/share_service.dart';

/// Sandwich detail screen - displays sandwich info with all components
class SandwichDetailScreen extends ConsumerWidget {
  final String sandwichId;

  const SandwichDetailScreen({super.key, required this.sandwichId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sandwichesAsync = ref.watch(allSandwichesProvider);

    return sandwichesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (sandwiches) {
        final sandwich = sandwiches.firstWhere(
          (s) => s.uuid == sandwichId,
          orElse: () => Sandwich()..name = '',
        );

        if (sandwich.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Sandwich not found')),
          );
        }

        return _SandwichDetailView(sandwich: sandwich);
      },
    );
  }
}

class _SandwichDetailView extends ConsumerWidget {
  final Sandwich sandwich;

  const _SandwichDetailView({required this.sandwich});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImage = sandwich.imageUrl != null && sandwich.imageUrl!.isNotEmpty;
    // Theme-aware shadows: drop shadow for dark, soft halo + outline for light
    final titleShadows = isDark 
        ? [
            const Shadow(blurRadius: 8, color: Colors.black87, offset: Offset(0, 1)),
            const Shadow(blurRadius: 16, color: Colors.black54),
          ]
        : [
            // Soft white halo for glow
            const Shadow(blurRadius: 4, color: Colors.white),
            const Shadow(blurRadius: 8, color: Colors.white70),
            // Black stroke for definition
            const Shadow(blurRadius: 0, color: Colors.black26, offset: Offset(-0.5, -0.5)),
            const Shadow(blurRadius: 0, color: Colors.black26, offset: Offset(0.5, 0.5)),
          ];
    final iconShadows = isDark 
        ? [const Shadow(blurRadius: 8, color: Colors.black54)]
        : [
            const Shadow(blurRadius: 1, color: Colors.black45),
            const Shadow(blurRadius: 0, color: Colors.black26, offset: Offset(-0.5, 0)),
            const Shadow(blurRadius: 0, color: Colors.black26, offset: Offset(0.5, 0)),
          ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasImage ? 250 : 150,
            pinned: true,
            leading: hasImage
                ? IconButton(
                    icon: Icon(Icons.arrow_back, shadows: iconShadows),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                sandwich.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: titleShadows,
                ),
              ),
              background: _buildHeaderBackground(theme),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  sandwich.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: sandwich.isFavorite ? theme.colorScheme.secondary : null,
                  shadows: hasImage ? iconShadows : null,
                ),
                onPressed: () {
                  ref.read(sandwichRepositoryProvider).toggleFavorite(sandwich);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  shadows: hasImage ? iconShadows : null,
                ),
                tooltip: 'I made this',
                onPressed: () async {
                  await ref.read(sandwichRepositoryProvider).incrementCookCount(sandwich);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logged cook for ${sandwich.name}!'),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.share,
                  shadows: hasImage ? iconShadows : null,
                ),
                onPressed: () => _shareSandwich(context, ref, sandwich),
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
                icon: Icon(
                  Icons.more_vert,
                  shadows: hasImage ? iconShadows : null,
                ),
              ),
            ],
          ),

          // Main content with responsive layout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SandwichComponentsGrid(sandwich: sandwich),
            ),
          ),
          
          // Notes section (if present)
          if (sandwich.notes != null && sandwich.notes!.isNotEmpty)
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
                          sandwich.notes!,
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
      ),
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    if (sandwich.imageUrl == null || sandwich.imageUrl!.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
      );
    }

    // Check if it's a URL or local file
    if (sandwich.imageUrl!.startsWith('http://') || sandwich.imageUrl!.startsWith('https://')) {
      return Image.network(
        sandwich.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    } else {
      return Image.file(
        File(sandwich.imageUrl!),
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
        AppRoutes.toSandwichEdit(context, sandwichId: sandwich.uuid);
        break;
      case 'duplicate':
        await _duplicateSandwich(context, ref);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Sandwich?'),
            content: Text('Are you sure you want to delete "${sandwich.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(sandwichRepositoryProvider).deleteSandwich(sandwich.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${sandwich.name} deleted')),
            );
          }
        }
        break;
    }
  }

  Future<void> _duplicateSandwich(BuildContext context, WidgetRef ref) async {
    final duplicate = Sandwich()
      ..uuid = '' // Will be generated on save
      ..name = '${sandwich.name} (Copy)'
      ..bread = sandwich.bread
      ..proteins = List.from(sandwich.proteins)
      ..vegetables = List.from(sandwich.vegetables)
      ..cheeses = List.from(sandwich.cheeses)
      ..condiments = List.from(sandwich.condiments)
      ..notes = sandwich.notes
      ..imageUrl = sandwich.imageUrl
      ..source = SandwichSource.personal
      ..tags = List.from(sandwich.tags);

    final repo = ref.read(sandwichRepositoryProvider);
    await repo.saveSandwich(duplicate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${duplicate.name}')),
      );
      // Navigate to the new sandwich
      AppRoutes.toSandwichDetail(context, duplicate.uuid);
    }
  }

  void _shareSandwich(BuildContext context, WidgetRef ref, Sandwich sandwich) {
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
                'Share "${sandwich.name}"',
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
                shareService.showSandwichQrCode(context, sandwich);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareSandwich(sandwich);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copySandwichShareLink(sandwich);
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
                shareService.shareSandwichAsText(sandwich);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid layout for sandwich components
/// Order: Bread - Condiments - Proteins - Cheese - Vegetables
/// Collapses to single column on narrow screens
class _SandwichComponentsGrid extends StatelessWidget {
  final Sandwich sandwich;

  const _SandwichComponentsGrid({required this.sandwich});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use side-by-side layout when width >= 500
        final isWide = constraints.maxWidth >= 500;
        
        if (isWide) {
          return _buildWideLayout(theme);
        } else {
          return _buildNarrowLayout(theme);
        }
      },
    );
  }

  Widget _buildWideLayout(ThemeData theme) {
    // Bread (full width) - Cheese | Condiments - Proteins | Vegetables
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bread section (full width, text only - no chip)
        if (sandwich.bread.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(theme, 'Bread', [sandwich.bread]),
          ),
        
        // Row 1: Cheese | Condiments
        if (sandwich.cheeses.isNotEmpty || sandwich.condiments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sandwich.cheeses.isNotEmpty)
                    Expanded(
                      child: _buildComponentSection(
                        theme,
                        sandwich.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
                        sandwich.cheeses,
                      ),
                    ),
                  if (sandwich.cheeses.isNotEmpty && sandwich.condiments.isNotEmpty)
                    const SizedBox(width: 16),
                  if (sandwich.condiments.isNotEmpty)
                    Expanded(
                      child: _buildComponentSection(
                        theme, 
                        sandwich.condiments.length == 1 ? 'Condiment' : 'Condiments',
                        sandwich.condiments,
                      ),
                    ),
                  // Fill empty space if only one column
                  if (sandwich.cheeses.isEmpty || sandwich.condiments.isEmpty)
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        
        // Row 2: Proteins | Vegetables
        if (sandwich.proteins.isNotEmpty || sandwich.vegetables.isNotEmpty)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sandwich.proteins.isNotEmpty)
                  Expanded(
                    child: _buildComponentSection(
                      theme,
                      sandwich.proteins.length == 1 ? 'Protein' : 'Proteins',
                      sandwich.proteins,
                    ),
                  ),
                if (sandwich.proteins.isNotEmpty && sandwich.vegetables.isNotEmpty)
                  const SizedBox(width: 16),
                if (sandwich.vegetables.isNotEmpty)
                  Expanded(
                    child: _buildComponentSection(
                      theme,
                      sandwich.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
                      sandwich.vegetables,
                    ),
                  ),
                // Fill empty space if only one column
                if (sandwich.proteins.isEmpty || sandwich.vegetables.isEmpty)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNarrowLayout(ThemeData theme) {
    // Single column layout for narrow screens
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sandwich.bread.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(theme, 'Bread', [sandwich.bread]),
          ),
        if (sandwich.cheeses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(
              theme,
              sandwich.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
              sandwich.cheeses,
            ),
          ),
        if (sandwich.condiments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(
              theme,
              sandwich.condiments.length == 1 ? 'Condiment' : 'Condiments',
              sandwich.condiments,
            ),
          ),
        if (sandwich.proteins.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(
              theme,
              sandwich.proteins.length == 1 ? 'Protein' : 'Proteins',
              sandwich.proteins,
            ),
          ),
        if (sandwich.vegetables.isNotEmpty)
          _buildComponentSection(
            theme,
            sandwich.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
            sandwich.vegetables,
          ),
      ],
    );
  }

  Widget _buildComponentSection(ThemeData theme, String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _SandwichIngredientList(items: items),
          ],
        ),
      ),
    );
  }
}

/// Capitalize the first letter of each word in a string
String _capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    // Don't capitalize common lowercase words in the middle
    final lower = word.toLowerCase();
    if (lower == 'of' || lower == 'and' || lower == 'or' || lower == 'the' || lower == 'a' || lower == 'an' || lower == 'to' || lower == 'for') {
      return lower;
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// A simple checkable list for sandwich ingredients
class _SandwichIngredientList extends StatefulWidget {
  final List<String> items;

  const _SandwichIngredientList({
    required this.items,
  });

  @override
  State<_SandwichIngredientList> createState() => _SandwichIngredientListState();
}

class _SandwichIngredientListState extends State<_SandwichIngredientList> {
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
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _capitalizeWords(item),
                    style: TextStyle(
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
