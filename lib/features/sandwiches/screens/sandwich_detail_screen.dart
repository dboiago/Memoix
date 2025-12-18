import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../settings/screens/settings_screen.dart';
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

class _SandwichDetailView extends ConsumerStatefulWidget {
  final Sandwich sandwich;

  const _SandwichDetailView({required this.sandwich});

  @override
  ConsumerState<_SandwichDetailView> createState() => _SandwichDetailViewState();
}

class _SandwichDetailViewState extends ConsumerState<_SandwichDetailView> {
  @override
  Widget build(BuildContext context) {
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final useSideBySide = ref.watch(useSideBySideProvider);
    final theme = Theme.of(context);
    final sandwich = widget.sandwich;
    final hasHeaderImage = showHeaderImages && sandwich.imageUrl != null && sandwich.imageUrl!.isNotEmpty;

    if (useSideBySide) {
      return _buildSideBySideLayout(context, theme, sandwich, hasHeaderImage);
    }
    
    return _buildStandardLayout(context, theme, sandwich, hasHeaderImage);
  }

  Widget _buildSideBySideLayout(BuildContext context, ThemeData theme, Sandwich sandwich, bool hasHeaderImage) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final headerHeight = hasHeaderImage ? 184.0 : 84.0; // Extra height for bread row

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: _buildAppBarActions(context, ref, theme, sandwich),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(headerHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasHeaderImage)
                SizedBox(
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildHeaderBackground(theme, sandwich),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                            stops: [0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sandwich.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Bread indicator
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          sandwich.bread.isNotEmpty ? sandwich.bread : 'No bread specified',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildSplitSandwichView(context, theme, sandwich, isCompact),
    );
  }

  Widget _buildSplitSandwichView(BuildContext context, ThemeData theme, Sandwich sandwich, bool isCompact) {
    final padding = isCompact ? 8.0 : 12.0;
    final headerHeight = isCompact ? 36.0 : 44.0;
    final headerStyle = isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final dividerPadding = isCompact ? 4.0 : 8.0;

    return Column(
      children: [
        // Headers row
        Container(
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: headerHeight,
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Text('Cheese / Condiments', style: headerStyle),
                ),
              ),
              SizedBox(width: dividerPadding * 2 + 1),
              Expanded(
                child: Container(
                  height: headerHeight,
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Text('Proteins / Vegetables', style: headerStyle),
                ),
              ),
            ],
          ),
        ),
        // Content row
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left column: Cheeses + Condiments
              Expanded(
                child: ListView(
                  primary: false,
                  padding: EdgeInsets.all(padding),
                  children: [
                    Text('Cheeses', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sandwich.cheeses.map((c) => _buildListItem(theme, c, isCompact)),
                    if (sandwich.cheeses.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Text('Condiments', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sandwich.condiments.map((c) => _buildListItem(theme, c, isCompact)),
                    if (sandwich.condiments.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    if (sandwich.notes != null && sandwich.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Notes', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(sandwich.notes!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              // Divider
              Padding(
                padding: EdgeInsets.symmetric(horizontal: dividerPadding),
                child: Container(
                  width: 1,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
              ),
              // Right column: Proteins + Vegetables
              Expanded(
                child: ListView(
                  primary: false,
                  padding: EdgeInsets.all(padding),
                  children: [
                    Text('Proteins', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sandwich.proteins.map((p) => _buildListItem(theme, p, isCompact)),
                    if (sandwich.proteins.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Text('Vegetables', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sandwich.vegetables.map((v) => _buildListItem(theme, v, isCompact)),
                    if (sandwich.vegetables.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(ThemeData theme, String text, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 2.0 : 4.0),
      child: Row(
        children: [
          Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, Sandwich sandwich, bool hasHeaderImage) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                sandwich.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 16,
                end: 160,
              ),
              expandedTitleScale: 1.3,
              background: hasHeaderImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildHeaderBackground(theme, sandwich),
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
            actions: _buildAppBarActions(context, ref, theme, sandwich),
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

  Widget _buildHeaderBackground(ThemeData theme, Sandwich sandwich) {
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

  List<Widget> _buildAppBarActions(BuildContext context, WidgetRef ref, ThemeData theme, Sandwich sandwich) {
    return [
      IconButton(
        icon: Icon(
          sandwich.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: sandwich.isFavorite ? theme.colorScheme.secondary : null,
        ),
        onPressed: () async {
          await ref.read(sandwichRepositoryProvider).toggleFavorite(sandwich);
          ref.invalidate(allSandwichesProvider);
        },
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_outline),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(sandwichRepositoryProvider).incrementCookCount(sandwich);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged cook for ${sandwich.name}!')),
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareSandwich(context, ref, sandwich),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, sandwich, value),
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
    ];
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, Sandwich sandwich, String action) async {
    switch (action) {
      case 'edit':
        AppRoutes.toSandwichEdit(context, sandwichId: sandwich.uuid);
        break;
      case 'duplicate':
        await _duplicateSandwich(context, ref, sandwich);
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

  Future<void> _duplicateSandwich(BuildContext context, WidgetRef ref, Sandwich sandwich) async {
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
