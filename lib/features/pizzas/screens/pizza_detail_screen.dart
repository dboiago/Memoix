import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';
import '../../sharing/services/share_service.dart';

/// Pizza detail screen - displays pizza info with cheeses, toppings, and notes
class PizzaDetailScreen extends ConsumerWidget {
  final String pizzaId;

  const PizzaDetailScreen({super.key, required this.pizzaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pizzasAsync = ref.watch(allPizzasProvider);

    return pizzasAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (pizzas) {
        final pizza = pizzas.firstWhere(
          (p) => p.uuid == pizzaId,
          orElse: () => Pizza()..name = '',
        );

        if (pizza.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Pizza not found')),
          );
        }

        return _PizzaDetailView(pizza: pizza);
      },
    );
  }
}

class _PizzaDetailView extends ConsumerStatefulWidget {
  final Pizza pizza;

  const _PizzaDetailView({required this.pizza});

  @override
  ConsumerState<_PizzaDetailView> createState() => _PizzaDetailViewState();
}

class _PizzaDetailViewState extends ConsumerState<_PizzaDetailView> {
  @override
  Widget build(BuildContext context) {
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final useSideBySide = ref.watch(useSideBySideProvider);
    final theme = Theme.of(context);
    final pizza = widget.pizza;
    final hasHeaderImage = showHeaderImages && pizza.imageUrl != null && pizza.imageUrl!.isNotEmpty;

    if (useSideBySide) {
      return _buildSideBySideLayout(context, theme, pizza, hasHeaderImage);
    }
    
    return _buildStandardLayout(context, theme, pizza, hasHeaderImage);
  }

  Widget _buildSideBySideLayout(BuildContext context, ThemeData theme, Pizza pizza, bool hasHeaderImage) {
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
                      image: pizza.imageUrl!.startsWith('http')
                          ? NetworkImage(pizza.imageUrl!) as ImageProvider
                          : FileImage(File(pizza.imageUrl!)),
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
                              children: _buildRichHeaderActions(context, ref, theme, pizza, hasHeaderImage),
                            ),
                          ],
                        ),

                        // Row 2: Title (wraps to 2 lines max)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            pizza.name,
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

                        // Row 3: Base sauce indicator
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: MemoixColors.forPizzaBaseDot(pizza.base.name),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                pizza.base.displayName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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
                  _PizzaComponentsGrid(pizza: pizza),
                  // Notes (full width)
                  if (pizza.notes != null && pizza.notes!.isNotEmpty) ...[
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
                                pizza.notes!,
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
  List<Widget> _buildRichHeaderActions(BuildContext context, WidgetRef ref, ThemeData theme, Pizza pizza, bool hasHeaderImage) {
    final iconColor = hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface;
    
    return [
      IconButton(
        icon: Icon(
          pizza.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: pizza.isFavorite ? theme.colorScheme.secondary : iconColor,
        ),
        onPressed: () async {
          await ref.read(pizzaRepositoryProvider).toggleFavorite(pizza);
          ref.invalidate(allPizzasProvider);
        },
      ),
      IconButton(
        icon: Icon(Icons.check_circle_outline, color: iconColor),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(pizzaRepositoryProvider).incrementCookCount(pizza);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged cook for ${pizza.name}!')),
            );
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.share, color: iconColor),
        onPressed: () => _sharePizza(context, ref, pizza),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, pizza, value),
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

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, Pizza pizza, bool hasHeaderImage) {
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
                  title: Text(
                    pizza.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                      color: hasHeaderImage && collapseRatio < 0.7 
                          ? theme.colorScheme.onSurfaceVariant 
                          : theme.colorScheme.onSurface,
                      shadows: hasHeaderImage && collapseRatio < 0.7
                          ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: hasHeaderImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildHeaderBackground(theme, pizza),
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
            actions: _buildAppBarActions(context, ref, theme, pizza),
          ),

          // Content - responsive grid layout for Sauce - Cheese - Toppings
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PizzaComponentsGrid(pizza: pizza),
            ),
          ),
          
          // Notes section (if present)
          if (pizza.notes != null && pizza.notes!.isNotEmpty)
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
                          pizza.notes!,
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

  Widget _buildHeaderBackground(ThemeData theme, Pizza pizza) {
    if (pizza.imageUrl == null || pizza.imageUrl!.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
      );
    }

    // Check if it's a URL or local file
    if (pizza.imageUrl!.startsWith('http://') || pizza.imageUrl!.startsWith('https://')) {
      return Image.network(
        pizza.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    } else {
      return Image.file(
        File(pizza.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
  }

  List<Widget> _buildAppBarActions(BuildContext context, WidgetRef ref, ThemeData theme, Pizza pizza) {
    return [
      IconButton(
        icon: Icon(
          pizza.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: pizza.isFavorite ? theme.colorScheme.secondary : null,
        ),
        onPressed: () async {
          await ref.read(pizzaRepositoryProvider).toggleFavorite(pizza);
          ref.invalidate(allPizzasProvider);
        },
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_outline),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(pizzaRepositoryProvider).incrementCookCount(pizza);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged cook for ${pizza.name}!')),
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _sharePizza(context, ref, pizza),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, pizza, value),
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
        icon: const Icon(Icons.more_vert),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, Pizza pizza, String action) async {
    switch (action) {
      case 'edit':
        AppRoutes.toPizzaEdit(context, pizzaId: pizza.uuid);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Pizza?'),
            content: Text('Are you sure you want to delete "${pizza.name}"?'),
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
          await ref.read(pizzaRepositoryProvider).deletePizza(pizza.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${pizza.name} deleted')),
            );
          }
        }
        break;
    }
  }

  void _sharePizza(BuildContext context, WidgetRef ref, Pizza pizza) {
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
                'Share "${pizza.name}"',
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
                shareService.showPizzaQrCode(context, pizza);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.sharePizza(pizza);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyPizzaShareLink(pizza);
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
                shareService.sharePizzaAsText(pizza);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Grid layout for pizza components
/// Always 50/50 side-by-side: Sauce | Cheese, Proteins | Vegetables
class _PizzaComponentsGrid extends StatelessWidget {
  final Pizza pizza;

  const _PizzaComponentsGrid({required this.pizza});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Sauce (50%) | Cheese (50%)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sauce section - always 50%
              Expanded(
                child: _buildComponentSection(theme, 'Sauce', [pizza.base.displayName]),
              ),
              const SizedBox(width: 16),
              // Cheese section - always 50%
              Expanded(
                child: pizza.cheeses.isNotEmpty
                    ? _buildComponentSection(
                        theme,
                        pizza.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
                        pizza.cheeses,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
        // Row 2: Proteins (50%) | Vegetables (50%)
        if (pizza.proteins.isNotEmpty || pizza.vegetables.isNotEmpty) ...[
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proteins section - always 50%
                Expanded(
                  child: pizza.proteins.isNotEmpty
                      ? _buildComponentSection(
                          theme,
                          'Proteins',
                          pizza.proteins,
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 16),
                // Vegetables section - always 50%
                Expanded(
                  child: pizza.vegetables.isNotEmpty
                      ? _buildComponentSection(
                          theme,
                          pizza.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
                          pizza.vegetables,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
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
            _PizzaIngredientList(items: items),
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

/// A simple checkable list for pizza ingredients (cheeses/toppings)
class _PizzaIngredientList extends StatefulWidget {
  final List<String> items;

  const _PizzaIngredientList({
    required this.items,
  });

  @override
  State<_PizzaIngredientList> createState() => _PizzaIngredientListState();
}

class _PizzaIngredientListState extends State<_PizzaIngredientList> {
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
