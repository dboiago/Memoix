import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../shared/widgets/memoix_header.dart';
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
    return Scaffold(
      // No appBar - we build the header as part of the body
      body: Column(
        children: [
          // 1. THE RICH HEADER - Fixed at top, does not scroll
          MemoixHeader(
            title: pizza.name,
            isFavorite: pizza.isFavorite,
            headerImage: hasHeaderImage ? pizza.imageUrl : null,
            onFavoritePressed: () async {
              await ref.read(pizzaRepositoryProvider).toggleFavorite(pizza);
              ref.invalidate(allPizzasProvider);
            },
            onLogCookPressed: () => _logCook(context, pizza),
            onSharePressed: () => _sharePizza(context, ref, pizza),
            onEditPressed: () => _handleMenuAction(context, ref, pizza, 'edit'),
            onDuplicatePressed: () => _handleMenuAction(context, ref, pizza, 'duplicate'),
            onDeletePressed: () => _handleMenuAction(context, ref, pizza, 'delete'),
          ),

          // 2. THE CONTENT - Scrollable, sits below header
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact metadata
                  _buildCompactMetadata(pizza, theme),
                  const SizedBox(height: 16),
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

  /// Build chip-style metadata (for normal scrolling views).
  Widget _buildChipMetadata(BuildContext context, Pizza pizza, ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final chipFontSize = isCompact ? 11.0 : 12.0;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Base sauce chip
        Chip(
          label: Text(pizza.base.displayName),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: chipFontSize,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// Build compact metadata row for side-by-side mode.
  Widget _buildCompactMetadata(Pizza pizza, ThemeData theme) {
    final textColor = theme.colorScheme.onSurfaceVariant;
    
    return Row(
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
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, Pizza pizza, bool hasHeaderImage) {
    return Scaffold(
      body: Column(
        children: [
          // 1. THE RICH HEADER - Fixed at top, does not scroll
          MemoixHeader(
            title: pizza.name,
            isFavorite: pizza.isFavorite,
            headerImage: hasHeaderImage ? pizza.imageUrl : null,
            onFavoritePressed: () async {
              await ref.read(pizzaRepositoryProvider).toggleFavorite(pizza);
              ref.invalidate(allPizzasProvider);
            },
            onLogCookPressed: () => _logCook(context, pizza),
            onSharePressed: () => _sharePizza(context, ref, pizza),
            onEditPressed: () => _handleMenuAction(context, ref, pizza, 'edit'),
            onDuplicatePressed: () => _handleMenuAction(context, ref, pizza, 'duplicate'),
            onDeletePressed: () => _handleMenuAction(context, ref, pizza, 'delete'),
          ),

          // 2. THE CONTENT - Scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Metadata chips
                _buildChipMetadata(context, pizza, theme),
                const SizedBox(height: 16),
                
                // Content - responsive grid layout for Sauce - Cheese - Toppings
                _PizzaComponentsGrid(pizza: pizza),
                
                // Notes section (if present)
                if (pizza.notes != null && pizza.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
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
                  
                // Bottom padding
                const SizedBox(height: 32),
              ],
            ),
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
              SnackBar(content: Text('Logged cook for ${pizza.name}')),
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

  Future<void> _logCook(BuildContext context, Pizza pizza) async {
    await ref.read(pizzaRepositoryProvider).incrementCookCount(pizza);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged cook for ${pizza.name}')),
      );
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
                    const SnackBar(content: Text('Link copied to clipboard')),
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
