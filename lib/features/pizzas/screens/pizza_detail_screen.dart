import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
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
    final headerHeight = hasHeaderImage ? 156.0 : 56.0;

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: _buildAppBarActions(context, ref, theme, pizza),
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
                      _buildHeaderBackground(theme, pizza),
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
                      pizza.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Base sauce indicator
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
                          pizza.base.displayName,
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
      body: _buildSplitPizzaView(context, theme, pizza, isCompact),
    );
  }

  Widget _buildSplitPizzaView(BuildContext context, ThemeData theme, Pizza pizza, bool isCompact) {
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
                  child: Text('Sauce / Cheese', style: headerStyle),
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
              // Left column: Sauce + Cheese
              Expanded(
                child: ListView(
                  primary: false,
                  padding: EdgeInsets.all(padding),
                  children: [
                    // Sauce
                    _buildListItem(theme, pizza.base.displayName, Icons.water_drop, isCompact),
                    const SizedBox(height: 16),
                    Text('Cheeses', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...pizza.cheeses.map((c) => _buildListItem(theme, c, null, isCompact)),
                    if (pizza.notes != null && pizza.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Notes', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(pizza.notes!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
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
                    ...pizza.proteins.map((p) => _buildListItem(theme, p, null, isCompact)),
                    if (pizza.proteins.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Text('Vegetables', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...pizza.vegetables.map((v) => _buildListItem(theme, v, null, isCompact)),
                    if (pizza.vegetables.isEmpty) Text('None', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(ThemeData theme, String text, IconData? icon, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 2.0 : 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ] else ...[
            Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, Pizza pizza, bool hasHeaderImage) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pizza.name,
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

/// Responsive grid layout for pizza components
/// Order: Sauce - Cheese - Toppings side-by-side
/// Collapses to single column on narrow screens
class _PizzaComponentsGrid extends StatelessWidget {
  final Pizza pizza;

  const _PizzaComponentsGrid({required this.pizza});

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
    // Row 1: Sauce | Cheese side-by-side
    // Row 2: Proteins | Vegetables side-by-side
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Sauce | Cheese
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sauce section
              Expanded(
                child: _buildComponentSection(theme, 'Sauce', [pizza.base.displayName]),
              ),
              const SizedBox(width: 16),
              // Cheese section
              if (pizza.cheeses.isNotEmpty)
                Expanded(
                  child: _buildComponentSection(
                    theme,
                    pizza.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
                    pizza.cheeses,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
        // Row 2: Proteins | Vegetables
        if (pizza.proteins.isNotEmpty || pizza.vegetables.isNotEmpty) ...[
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proteins section
                if (pizza.proteins.isNotEmpty)
                  Expanded(
                    child: _buildComponentSection(
                      theme,
                      pizza.proteins.length == 1 ? 'Protein' : 'Proteins',
                      pizza.proteins,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 16),
                // Vegetables section
                if (pizza.vegetables.isNotEmpty)
                  Expanded(
                    child: _buildComponentSection(
                      theme,
                      pizza.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
                      pizza.vegetables,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNarrowLayout(ThemeData theme) {
    // Single column layout for narrow screens
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sauce section
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildComponentSection(theme, 'Sauce', [pizza.base.displayName]),
        ),
        // Cheese section
        if (pizza.cheeses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(
              theme,
              pizza.cheeses.length == 1 ? 'Cheese' : 'Cheeses',
              pizza.cheeses,
            ),
          ),
        // Proteins section
        if (pizza.proteins.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildComponentSection(
              theme,
              pizza.proteins.length == 1 ? 'Protein' : 'Proteins',
              pizza.proteins,
            ),
          ),
        // Vegetables section
        if (pizza.vegetables.isNotEmpty)
          _buildComponentSection(
            theme,
            pizza.vegetables.length == 1 ? 'Vegetable' : 'Vegetables',
            pizza.vegetables,
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
