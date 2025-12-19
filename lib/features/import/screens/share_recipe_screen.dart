import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/category.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../cellar/models/cellar_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../sharing/services/share_service.dart';
import '../../../core/widgets/memoix_snackbar.dart';

/// Unified shareable item wrapper for all model types
class ShareableItem {
  final String uuid;
  final String name;
  final String category;
  final String? subtitle;
  final ShareableType type;
  final dynamic original;

  ShareableItem({
    required this.uuid,
    required this.name,
    required this.category,
    this.subtitle,
    required this.type,
    required this.original,
  });

  String get displayCategory {
    if (category.isEmpty) return type.displayName;
    return category[0].toUpperCase() + category.substring(1);
  }
}

enum ShareableType {
  recipe,
  pizza,
  sandwich,
  smoking,
  modernist,
  cellar,
  cheese;

  String get displayName {
    switch (this) {
      case ShareableType.recipe:
        return 'Recipes';
      case ShareableType.pizza:
        return 'Pizzas';
      case ShareableType.sandwich:
        return 'Sandwiches';
      case ShareableType.smoking:
        return 'Smoking';
      case ShareableType.modernist:
        return 'Modernist';
      case ShareableType.cellar:
        return 'Cellar';
      case ShareableType.cheese:
        return 'Cheese';
    }
  }

  String get singularName {
    switch (this) {
      case ShareableType.recipe:
        return 'Recipe';
      case ShareableType.pizza:
        return 'Pizza';
      case ShareableType.sandwich:
        return 'Sandwich';
      case ShareableType.smoking:
        return 'Smoking Recipe';
      case ShareableType.modernist:
        return 'Modernist Recipe';
      case ShareableType.cellar:
        return 'Cellar Entry';
      case ShareableType.cheese:
        return 'Cheese';
    }
  }
}

class ShareRecipeScreen extends ConsumerStatefulWidget {
  final String? recipeId;

  const ShareRecipeScreen({super.key, this.recipeId});

  @override
  ConsumerState<ShareRecipeScreen> createState() => _ShareRecipeScreenState();
}

class _ShareRecipeScreenState extends ConsumerState<ShareRecipeScreen> {
  ShareableItem? _selectedItem;
  String? _shareLink;
  bool _isGenerating = false;
  bool _qrCodeTooLong = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _loadRecipe(widget.recipeId!);
    }
  }

  Future<void> _loadRecipe(String recipeId) async {
    final repo = ref.read(recipeRepositoryProvider);
    final recipe = await repo.getRecipeByUuid(recipeId);
    if (recipe != null) {
      setState(() => _selectedItem = ShareableItem(
        uuid: recipe.uuid,
        name: recipe.name,
        category: recipe.course,
        subtitle: recipe.cuisine,
        type: ShareableType.recipe,
        original: recipe,
      ));
      _generateShareLink();
    }
  }

  Future<void> _generateShareLink() async {
    if (_selectedItem == null) return;

    setState(() {
      _isGenerating = true;
      _qrCodeTooLong = false;
    });

    try {
      final shareService = ref.read(shareServiceProvider);
      String link;

      switch (_selectedItem!.type) {
        case ShareableType.recipe:
          link = shareService.generateShareLink(_selectedItem!.original as Recipe);
          break;
        case ShareableType.pizza:
          link = shareService.generatePizzaShareLink(_selectedItem!.original as Pizza);
          break;
        case ShareableType.sandwich:
          link = shareService.generateSandwichShareLink(_selectedItem!.original as Sandwich);
          break;
        case ShareableType.smoking:
          link = shareService.generateSmokingShareLink(_selectedItem!.original as SmokingRecipe);
          break;
        case ShareableType.modernist:
          link = shareService.generateModernistShareLink(_selectedItem!.original as ModernistRecipe);
          break;
        case ShareableType.cellar:
          link = shareService.generateCellarShareLink(_selectedItem!.original as CellarEntry);
          break;
        case ShareableType.cheese:
          link = shareService.generateCheeseShareLink(_selectedItem!.original as CheeseEntry);
          break;
      }

      final isTooLong = link.length > 2000;

      setState(() {
        _shareLink = link;
        _qrCodeTooLong = isTooLong;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      MemoixSnackBar.showError('Failed to generate link: $e');
    }
  }

  List<ShareableItem> _buildShareableItems(WidgetRef ref) {
    final items = <ShareableItem>[];

    // Recipes
    final recipes = ref.watch(allRecipesProvider);
    recipes.whenData((list) {
      for (final r in list) {
        items.add(ShareableItem(
          uuid: r.uuid,
          name: r.name,
          category: r.course,
          subtitle: r.cuisine,
          type: ShareableType.recipe,
          original: r,
        ));
      }
    });

    // Pizzas
    final pizzas = ref.watch(allPizzasProvider);
    pizzas.whenData((list) {
      for (final p in list) {
        items.add(ShareableItem(
          uuid: p.uuid,
          name: p.name,
          category: 'Pizzas',
          subtitle: p.base.displayName,
          type: ShareableType.pizza,
          original: p,
        ));
      }
    });

    // Sandwiches
    final sandwiches = ref.watch(allSandwichesProvider);
    sandwiches.whenData((list) {
      for (final s in list) {
        items.add(ShareableItem(
          uuid: s.uuid,
          name: s.name,
          category: 'Sandwiches',
          subtitle: s.bread,
          type: ShareableType.sandwich,
          original: s,
        ));
      }
    });

    // Smoking
    final smoking = ref.watch(allSmokingRecipesProvider);
    smoking.whenData((list) {
      for (final s in list) {
        items.add(ShareableItem(
          uuid: s.uuid,
          name: s.name,
          category: 'Smoking',
          subtitle: s.item ?? s.category,
          type: ShareableType.smoking,
          original: s,
        ));
      }
    });

    // Modernist
    final modernist = ref.watch(allModernistRecipesProvider);
    modernist.whenData((list) {
      for (final m in list) {
        items.add(ShareableItem(
          uuid: m.uuid,
          name: m.name,
          category: 'Modernist',
          subtitle: m.technique,
          type: ShareableType.modernist,
          original: m,
        ));
      }
    });

    // Cellar
    final cellar = ref.watch(allCellarEntriesProvider);
    cellar.whenData((list) {
      for (final c in list) {
        items.add(ShareableItem(
          uuid: c.uuid,
          name: c.name,
          category: 'Cellar',
          subtitle: c.producer ?? c.category,
          type: ShareableType.cellar,
          original: c,
        ));
      }
    });

    // Cheese
    final cheese = ref.watch(allCheeseEntriesProvider);
    cheese.whenData((list) {
      for (final c in list) {
        items.add(ShareableItem(
          uuid: c.uuid,
          name: c.name,
          category: 'Cheese',
          subtitle: c.country ?? c.milk,
          type: ShareableType.cheese,
          original: c,
        ));
      }
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _selectedItem == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedItem != null) {
          setState(() {
            _selectedItem = null;
            _shareLink = null;
            _qrCodeTooLong = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Share'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedItem != null) {
                setState(() {
                  _selectedItem = null;
                  _shareLink = null;
                  _qrCodeTooLong = false;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: _selectedItem == null
            ? _buildItemSelector(theme)
            : _buildShareOptions(theme),
      ),
    );
  }

  Widget _buildItemSelector(ThemeData theme) {
    final allItems = _buildShareableItems(ref);
    allItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select an item to share',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search...',
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', theme),
                ...Category.defaults
                    .where((c) => allItems.any((item) =>
                        item.type == ShareableType.recipe &&
                        (item.category.toLowerCase() == c.slug ||
                            item.category.toLowerCase() == c.name.toLowerCase())))
                    .map((c) => _buildFilterChip(c.name, theme)),
                if (allItems.any((i) => i.type == ShareableType.pizza))
                  _buildFilterChip('Pizzas', theme),
                if (allItems.any((i) => i.type == ShareableType.sandwich))
                  _buildFilterChip('Sandwiches', theme),
                if (allItems.any((i) => i.type == ShareableType.smoking))
                  _buildFilterChip('Smoking', theme),
                if (allItems.any((i) => i.type == ShareableType.modernist))
                  _buildFilterChip('Modernist', theme),
                if (allItems.any((i) => i.type == ShareableType.cellar))
                  _buildFilterChip('Cellar', theme),
                if (allItems.any((i) => i.type == ShareableType.cheese))
                  _buildFilterChip('Cheese', theme),
              ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        Expanded(
          child: _buildItemList(allItems, theme),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, ThemeData theme) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = label);
        },
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
        showCheckmark: false,
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildItemList(List<ShareableItem> allItems, ThemeData theme) {
    final filtered = allItems.where((item) {
      if (_selectedCategory != 'All') {
        final catLower = _selectedCategory.toLowerCase();
        if (catLower == 'pizzas' && item.type != ShareableType.pizza) return false;
        if (catLower == 'sandwiches' && item.type != ShareableType.sandwich) return false;
        if (catLower == 'smoking' && item.type != ShareableType.smoking) return false;
        if (catLower == 'modernist' && item.type != ShareableType.modernist) return false;
        if (catLower == 'cellar' && item.type != ShareableType.cellar) return false;
        if (catLower == 'cheese' && item.type != ShareableType.cheese) return false;

        if (item.type == ShareableType.recipe) {
          final matchingCat = Category.defaults.firstWhere(
            (c) => c.name.toLowerCase() == catLower,
            orElse: () => Category.create(slug: '', name: '', colorValue: 0),
          );
          final itemCatLower = item.category.toLowerCase();
          if (matchingCat.slug.isNotEmpty) {
            if (itemCatLower != catLower && itemCatLower != matchingCat.slug) {
              return false;
            }
          } else if (itemCatLower != catLower) {
            return false;
          }
        }
      }

      if (_searchQuery.isNotEmpty) {
        final nameLower = item.name.toLowerCase();
        final subtitleLower = (item.subtitle ?? '').toLowerCase();
        if (!nameLower.contains(_searchQuery) &&
            !subtitleLower.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'No items found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<ShareableItem>>{};

    for (final cat in Category.defaults) {
      final matchingItems = filtered.where((item) {
        if (item.type != ShareableType.recipe) return false;
        final catLower = item.category.toLowerCase();
        return catLower == cat.slug || catLower == cat.name.toLowerCase();
      }).toList();
      if (matchingItems.isNotEmpty) {
        grouped[cat.name] = matchingItems;
      }
    }

    final pizzaItems = filtered.where((i) => i.type == ShareableType.pizza).toList();
    if (pizzaItems.isNotEmpty) grouped['Pizzas'] = pizzaItems;

    final sandwichItems = filtered.where((i) => i.type == ShareableType.sandwich).toList();
    if (sandwichItems.isNotEmpty) grouped['Sandwiches'] = sandwichItems;

    final smokingItems = filtered.where((i) => i.type == ShareableType.smoking).toList();
    if (smokingItems.isNotEmpty) grouped['Smoking'] = smokingItems;

    final modernistItems = filtered.where((i) => i.type == ShareableType.modernist).toList();
    if (modernistItems.isNotEmpty) grouped['Modernist'] = modernistItems;

    final cellarItems = filtered.where((i) => i.type == ShareableType.cellar).toList();
    if (cellarItems.isNotEmpty) grouped['Cellar'] = cellarItems;

    final cheeseItems = filtered.where((i) => i.type == ShareableType.cheese).toList();
    if (cheeseItems.isNotEmpty) grouped['Cheese'] = cheeseItems;

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final category = grouped.keys.elementAt(index);
        final categoryItems = grouped[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedCategory == 'All') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  category,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            ...categoryItems.map((item) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() => _selectedItem = item);
                    _generateShareLink();
                  },
                )),
          ],
        );
      },
    );
  }

  Widget _buildShareOptions(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              title: Text(
                _selectedItem!.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_selectedItem!.type.singularName),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedItem = null;
                    _shareLink = null;
                    _qrCodeTooLong = false;
                  });
                },
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_shareLink != null && !_qrCodeTooLong) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _shareLink!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code to import',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ] else if (_qrCodeTooLong) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Too large for QR code',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This item has too much data to fit in a QR code. Use "Share Link" or "As Text" instead.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isGenerating) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          const SizedBox(height: 32),

          Text(
            'Share via',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.share,
                  label: 'Share Link',
                  onTap: _shareLink == null ? null : _shareViaLink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareButton(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  onTap: _shareLink == null ? null : _copyLink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.text_snippet,
                  label: 'As Text',
                  onTap: _shareAsText,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  void _shareViaLink() {
    if (_shareLink == null || _selectedItem == null) return;
    Share.share(
      'Check out this ${_selectedItem!.type.singularName.toLowerCase()}: ${_selectedItem!.name}\n\n$_shareLink',
      subject: _selectedItem!.name,
    );
  }

  void _copyLink() {
    if (_shareLink == null) return;
    Clipboard.setData(ClipboardData(text: _shareLink!));
    MemoixSnackBar.show('Link copied to clipboard');
  }

  void _shareAsText() {
    if (_selectedItem == null) return;

    final buffer = StringBuffer();

    switch (_selectedItem!.type) {
      case ShareableType.recipe:
        _formatRecipeAsText(buffer, _selectedItem!.original as Recipe);
        break;
      case ShareableType.pizza:
        _formatPizzaAsText(buffer, _selectedItem!.original as Pizza);
        break;
      case ShareableType.sandwich:
        _formatSandwichAsText(buffer, _selectedItem!.original as Sandwich);
        break;
      case ShareableType.smoking:
        _formatSmokingAsText(buffer, _selectedItem!.original as SmokingRecipe);
        break;
      case ShareableType.modernist:
        _formatModernistAsText(buffer, _selectedItem!.original as ModernistRecipe);
        break;
      case ShareableType.cellar:
        _formatCellarAsText(buffer, _selectedItem!.original as CellarEntry);
        break;
      case ShareableType.cheese:
        _formatCheeseAsText(buffer, _selectedItem!.original as CheeseEntry);
        break;
    }

    buffer.writeln();
    buffer.writeln('Shared from Memoix');

    Share.share(buffer.toString(), subject: _selectedItem!.name);
  }

  void _formatRecipeAsText(StringBuffer buffer, Recipe recipe) {
    buffer.writeln('${recipe.name}');
    buffer.writeln();
    buffer.writeln('Course: ${recipe.course}');
    if (recipe.cuisine != null) buffer.writeln('Cuisine: ${recipe.cuisine}');
    if (recipe.serves != null) buffer.writeln('Serves: ${recipe.serves}');
    if (recipe.time != null) buffer.writeln('Time: ${recipe.time}');
    buffer.writeln();

    buffer.writeln('Ingredients:');
    for (final ingredient in recipe.ingredients) {
      final amount = ingredient.amount != null ? '${ingredient.amount} ' : '';
      final unit = ingredient.unit != null ? '${ingredient.unit} ' : '';
      buffer.writeln('• $amount$unit${ingredient.name}');
    }
    buffer.writeln();

    buffer.writeln('Directions:');
    for (var i = 0; i < recipe.directions.length; i++) {
      buffer.writeln('${i + 1}. ${recipe.directions[i]}');
    }
  }

  void _formatPizzaAsText(StringBuffer buffer, Pizza pizza) {
    buffer.writeln('${pizza.name}');
    buffer.writeln();
    buffer.writeln('Base: ${pizza.base.displayName}');

    if (pizza.cheeses.isNotEmpty) {
      buffer.writeln('\nCheeses:');
      for (final cheese in pizza.cheeses) {
        buffer.writeln('• $cheese');
      }
    }
    if (pizza.proteins.isNotEmpty) {
      buffer.writeln('\nProteins:');
      for (final protein in pizza.proteins) {
        buffer.writeln('• $protein');
      }
    }
    if (pizza.vegetables.isNotEmpty) {
      buffer.writeln('\nVegetables:');
      for (final veg in pizza.vegetables) {
        buffer.writeln('• $veg');
      }
    }
    if (pizza.notes != null && pizza.notes!.isNotEmpty) {
      buffer.writeln('\nNotes: ${pizza.notes}');
    }
  }

  void _formatSandwichAsText(StringBuffer buffer, Sandwich sandwich) {
    buffer.writeln('${sandwich.name}');
    buffer.writeln();
    buffer.writeln('Bread: ${sandwich.bread}');

    if (sandwich.proteins.isNotEmpty) {
      buffer.writeln('\nProteins:');
      for (final protein in sandwich.proteins) {
        buffer.writeln('• $protein');
      }
    }
    if (sandwich.cheeses.isNotEmpty) {
      buffer.writeln('\nCheeses:');
      for (final cheese in sandwich.cheeses) {
        buffer.writeln('• $cheese');
      }
    }
    if (sandwich.vegetables.isNotEmpty) {
      buffer.writeln('\nVegetables:');
      for (final veg in sandwich.vegetables) {
        buffer.writeln('• $veg');
      }
    }
    if (sandwich.condiments.isNotEmpty) {
      buffer.writeln('\nCondiments:');
      for (final condiment in sandwich.condiments) {
        buffer.writeln('• $condiment');
      }
    }
    if (sandwich.notes != null && sandwich.notes!.isNotEmpty) {
      buffer.writeln('\nNotes: ${sandwich.notes}');
    }
  }

  void _formatSmokingAsText(StringBuffer buffer, SmokingRecipe recipe) {
    buffer.writeln('${recipe.name}');
    buffer.writeln();
    if (recipe.item != null) buffer.writeln('Item: ${recipe.item}');
    buffer.writeln('Temperature: ${recipe.temperature}');
    buffer.writeln('Time: ${recipe.time}');
    buffer.writeln('Wood: ${recipe.wood}');

    if (recipe.seasonings.isNotEmpty) {
      buffer.writeln('\nSeasonings:');
      for (final s in recipe.seasonings) {
        final amount = s.amount != null && s.amount!.isNotEmpty ? '${s.amount} ' : '';
        buffer.writeln('• $amount${s.name}');
      }
    }
    if (recipe.directions.isNotEmpty) {
      buffer.writeln('\nDirections:');
      for (var i = 0; i < recipe.directions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.directions[i]}');
      }
    }
    if (recipe.notes != null && recipe.notes!.isNotEmpty) {
      buffer.writeln('\nNotes: ${recipe.notes}');
    }
  }

  void _formatModernistAsText(StringBuffer buffer, ModernistRecipe recipe) {
    buffer.writeln('${recipe.name}');
    buffer.writeln();
    buffer.writeln('Type: ${recipe.type.displayName}');
    if (recipe.technique != null) buffer.writeln('Technique: ${recipe.technique}');
    if (recipe.serves != null) buffer.writeln('Serves: ${recipe.serves}');
    if (recipe.time != null) buffer.writeln('Time: ${recipe.time}');

    if (recipe.equipment.isNotEmpty) {
      buffer.writeln('\nEquipment:');
      for (final e in recipe.equipment) {
        buffer.writeln('• $e');
      }
    }
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln('\nIngredients:');
      for (final ing in recipe.ingredients) {
        buffer.writeln('• ${ing.displayText}');
      }
    }
    if (recipe.directions.isNotEmpty) {
      buffer.writeln('\nDirections:');
      for (var i = 0; i < recipe.directions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.directions[i]}');
      }
    }
    if (recipe.scienceNotes != null && recipe.scienceNotes!.isNotEmpty) {
      buffer.writeln('\nScience Notes: ${recipe.scienceNotes}');
    }
    if (recipe.notes != null && recipe.notes!.isNotEmpty) {
      buffer.writeln('\nNotes: ${recipe.notes}');
    }
  }

  void _formatCellarAsText(StringBuffer buffer, CellarEntry entry) {
    buffer.writeln('${entry.name}');
    buffer.writeln();
    if (entry.producer != null) buffer.writeln('Producer: ${entry.producer}');
    if (entry.category != null) buffer.writeln('Category: ${entry.category}');
    if (entry.ageVintage != null) buffer.writeln('Age/Vintage: ${entry.ageVintage}');
    if (entry.abv != null) buffer.writeln('ABV: ${entry.abv}');
    if (entry.tastingNotes != null && entry.tastingNotes!.isNotEmpty) {
      buffer.writeln('\nTasting Notes: ${entry.tastingNotes}');
    }
    buffer.writeln('\nWould buy again: ${entry.buy ? 'Yes' : 'No'}');
  }

  void _formatCheeseAsText(StringBuffer buffer, CheeseEntry entry) {
    buffer.writeln('${entry.name}');
    buffer.writeln();
    if (entry.country != null) buffer.writeln('Country: ${entry.country}');
    if (entry.milk != null) buffer.writeln('Milk: ${entry.milk}');
    if (entry.texture != null) buffer.writeln('Texture: ${entry.texture}');
    if (entry.type != null) buffer.writeln('Type: ${entry.type}');
    if (entry.flavour != null && entry.flavour!.isNotEmpty) {
      buffer.writeln('\nFlavour: ${entry.flavour}');
    }
    buffer.writeln('\nWould buy again: ${entry.buy ? 'Yes' : 'No'}');
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
