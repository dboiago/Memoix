import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
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
          orElse: () => Sandwich()
            ..uuid = ''
            ..name = '',
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
    // Scale font size with screen width: 20px at 320, up to 28px at 1200+
    final baseFontSize = (screenWidth / 40).clamp(20.0, 28.0);

    return Scaffold(
      // No appBar - we build the header as part of the body
      body: Column(
        children: [
          // 1. THE RICH HEADER - Fixed at top, does not scroll
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              // Default solid color from theme
              color: theme.colorScheme.surfaceContainerHighest,
              // Optional background image if user has set one
              image: hasHeaderImage
                  ? DecorationImage(
                      image: sandwich.imageUrl!.startsWith('http')
                          ? NetworkImage(sandwich.imageUrl!) as ImageProvider
                          : FileImage(File(sandwich.imageUrl!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Semi-transparent overlay for text legibility when image is present
                if (hasHeaderImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Content inside SafeArea (icons and title stay within safe bounds)
                SafeArea(
                  bottom: false, // Only pad for status bar, not bottom
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Navigation Icon (Left) + Action Icons (Right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            // Action icons row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _buildRichHeaderActions(context, ref, theme, sandwich, hasHeaderImage),
                            ),
                          ],
                        ),

                        // Row 2: Title (wraps to 2 lines max)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            sandwich.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: baseFontSize,
                              color: hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                              shadows: hasHeaderImage
                                  ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Row 3: Protein indicator
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
                          child: _buildProteinIndicator(sandwich, theme, overrideColor: hasHeaderImage ? theme.colorScheme.onSurfaceVariant : null),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. THE CONTENT - Scrollable, sits below header
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use same grid as normal mode
                  _SandwichComponentsGrid(sandwich: sandwich),
                  // Notes (full width)
                  if (sandwich.notes != null && sandwich.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sandwich.notes!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action icons for the Rich Header (with appropriate colors for image/no-image states)
  List<Widget> _buildRichHeaderActions(BuildContext context, WidgetRef ref, ThemeData theme, Sandwich sandwich, bool hasHeaderImage) {
    final iconColor = hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface;
    
    return [
      IconButton(
        icon: Icon(
          sandwich.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: sandwich.isFavorite ? theme.colorScheme.secondary : iconColor,
        ),
        onPressed: () async {
          await ref.read(sandwichRepositoryProvider).toggleFavorite(sandwich);
          ref.invalidate(allSandwichesProvider);
        },
      ),
      IconButton(
        icon: Icon(Icons.check_circle_outline, color: iconColor),
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
        icon: Icon(Icons.share, color: iconColor),
        onPressed: () => _shareSandwich(context, ref, sandwich),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, sandwich, value),
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
        icon: Icon(Icons.more_vert, color: iconColor),
      ),
    ];
  }

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, Sandwich sandwich, bool hasHeaderImage) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                // Scale font: 20px at 320, up to 28px at 1200+
                final expandedFontSize = (screenWidth / 40).clamp(20.0, 28.0);
                final collapsedFontSize = (screenWidth / 50).clamp(18.0, 24.0);
                
                // Calculate how collapsed we are (0 = fully expanded, 1 = fully collapsed)
                final maxExtent = hasHeaderImage ? 250.0 : 120.0;
                final minExtent = kToolbarHeight + MediaQuery.of(context).padding.top;
                final currentExtent = constraints.maxHeight;
                final collapseRatio = ((maxExtent - currentExtent) / (maxExtent - minExtent)).clamp(0.0, 1.0);
                
                // Interpolate font size
                final fontSize = expandedFontSize - (expandedFontSize - collapsedFontSize) * collapseRatio;
                
                return FlexibleSpaceBar(
                  titlePadding: EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 12,
                    end: 100,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            sandwich.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: hasHeaderImage || collapseRatio < 0.7 
                                  ? Colors.white 
                                  : theme.colorScheme.onSurface,
                              shadows: hasHeaderImage && collapseRatio < 0.7
                                  ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                );
              },
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

  /// Build protein indicator matching list view logic
  /// [overrideColor] - optional color to use for text when over an image
  Widget _buildProteinIndicator(Sandwich sandwich, ThemeData theme, {Color? overrideColor}) {
    final proteins = sandwich.proteins;
    final cheeses = sandwich.cheeses;
    final textColor = overrideColor ?? theme.colorScheme.onSurfaceVariant;
    
    String label;
    Color dotColor;
    
    if (proteins.isEmpty) {
      // Vegetarian - show "Cheese"
      if (cheeses.isNotEmpty) {
        label = 'Cheese';
        dotColor = MemoixColors.cheese;
      } else {
        return const SizedBox.shrink();
      }
    } else if (proteins.length == 1) {
      // Single protein - show it with protein-specific color
      label = proteins.first;
      dotColor = MemoixColors.forProteinDot(proteins.first);
    } else {
      // Multiple proteins - show "Assorted" with first protein's color
      label = 'Assorted';
      dotColor = MemoixColors.forProteinDot(proteins.first);
    }
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor,
          ),
        ),
      ],
    );
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

/// Grid layout for sandwich components
/// Always 50/50 side-by-side: Bread (full), Cheese | Condiments, Proteins | Vegetables
class _SandwichComponentsGrid extends StatelessWidget {
  final Sandwich sandwich;

  const _SandwichComponentsGrid({required this.sandwich});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bread section (full width)
        if (sandwich.bread.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(theme, 'Bread', [sandwich.bread]),
          ),
        
        // Row 1: Cheese (50%) | Condiments (50%)
        if (sandwich.cheeses.isNotEmpty || sandwich.condiments.isNotEmpty) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cheese section - always 50%
                Expanded(
                  child: sandwich.cheeses.isNotEmpty
                      ? _buildComponentSection(
                          theme,
                          sandwich.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
                          sandwich.cheeses,
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 16),
                // Condiments section - always 50%
                Expanded(
                  child: sandwich.condiments.isNotEmpty
                      ? _buildComponentSection(
                          theme, 
                          'Condiments',
                          sandwich.condiments,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Row 2: Proteins (50%) | Vegetables (50%)
        if (sandwich.proteins.isNotEmpty || sandwich.vegetables.isNotEmpty)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proteins section - always 50%
                Expanded(
                  child: sandwich.proteins.isNotEmpty
                      ? _buildComponentSection(
                          theme,
                          'Proteins',
                          sandwich.proteins,
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 16),
                // Vegetables section - always 50%
                Expanded(
                  child: sandwich.vegetables.isNotEmpty
                      ? _buildComponentSection(
                          theme,
                          sandwich.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
                          sandwich.vegetables,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
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
