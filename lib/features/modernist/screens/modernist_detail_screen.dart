import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/unit_normalizer.dart';
import '../../settings/screens/settings_screen.dart';
import '../../sharing/services/share_service.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import '../widgets/split_modernist_view.dart';
import 'modernist_edit_screen.dart';

/// Detail screen for viewing a modernist recipe - follows Mains pattern exactly
class ModernistDetailScreen extends ConsumerStatefulWidget {
  final int recipeId;

  const ModernistDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  ConsumerState<ModernistDetailScreen> createState() => _ModernistDetailScreenState();
}

class _ModernistDetailScreenState extends ConsumerState<ModernistDetailScreen> {
  final Set<int> _completedDirections = {};
  final Set<int> _checkedIngredients = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stepImagesKey = GlobalKey();
  bool _equipmentExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipeAsync = ref.watch(modernistRecipeProvider(widget.recipeId));

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (recipe) {
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        return _buildDetailView(context, theme, recipe);
      },
    );
  }

  Widget _buildDetailView(BuildContext context, ThemeData theme, ModernistRecipe recipe) {
    final useSideBySide = ref.watch(useSideBySideProvider);
    
    // Use side-by-side layout when enabled
    if (useSideBySide) {
      return _buildSideBySideLayout(context, theme, recipe);
    }
    
    return _buildStandardLayout(context, theme, recipe);
  }

  Widget _buildSideBySideLayout(BuildContext context, ThemeData theme, ModernistRecipe recipe) {
    final hasStepImages = recipe.stepImages.isNotEmpty;
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final headerImage = recipe.headerImage ?? recipe.imageUrl;
    final hasHeaderImage = showHeaderImages && headerImage != null && headerImage.isNotEmpty;
    final hasEquipment = recipe.equipment.isNotEmpty;
    
    // Calculate header height based on content (equipment moved to body)
    double headerHeight = hasHeaderImage ? 100.0 : 0.0;
    headerHeight += 56.0; // Title + metadata row

    return Scaffold(
      appBar: AppBar(
        // No title in the main area - it goes in bottom
        title: null,
        actions: _buildAppBarActions(context, recipe, theme),
        // Recipe name on its own line below the back arrow and actions
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(headerHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header image if enabled
              if (hasHeaderImage)
                SizedBox(
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSingleImage(headerImage!),
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
              // Recipe title with metadata
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Compact metadata row with dots
                    _buildCompactMetadataRow(recipe, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Collapsible equipment section (above the split view)
          if (hasEquipment)
            _buildCollapsibleEquipment(recipe, theme),
          // Main content
          Expanded(
            child: SplitModernistView(
              recipe: recipe,
              onScrollToImage: hasStepImages ? (stepIndex) => _scrollToAndShowImage(recipe, stepIndex) : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Build compact metadata row for side-by-side mode
  Widget _buildCompactMetadataRow(ModernistRecipe recipe, ThemeData theme) {
    final metadataItems = <InlineSpan>[];
    
    // Always show type with colored indicator (Concept or Technique)
    final typeColor = recipe.type == ModernistType.technique 
        ? theme.colorScheme.tertiary 
        : theme.colorScheme.primary;
    metadataItems.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: typeColor,
          shape: BoxShape.circle,
        ),
      ),
    ));
    metadataItems.add(TextSpan(text: recipe.type.displayName));
    
    // Add technique category with spacing
    if (recipe.technique != null && recipe.technique!.isNotEmpty) {
      metadataItems.add(const TextSpan(text: '   '));
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.science_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
      ));
      metadataItems.add(TextSpan(text: ' ${recipe.technique!}'));
    }
    
    // Add serves (normalized to just number)
    if (recipe.serves != null && recipe.serves!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeServes(recipe.serves!);
      if (normalized.isNotEmpty) {
        metadataItems.add(const TextSpan(text: '   '));
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.people, size: 12, color: theme.colorScheme.onSurfaceVariant),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }
    
    // Add time (normalized to compact format with clock icon)
    if (recipe.time != null && recipe.time!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeTime(recipe.time!);
      if (normalized.isNotEmpty) {
        metadataItems.add(const TextSpan(text: '   '));
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.schedule, size: 12, color: theme.colorScheme.onSurfaceVariant),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }
    
    // Add difficulty
    if (recipe.difficulty != null && recipe.difficulty!.isNotEmpty) {
      metadataItems.add(const TextSpan(text: '   '));
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.signal_cellular_alt, size: 12, color: theme.colorScheme.onSurfaceVariant),
      ));
      metadataItems.add(TextSpan(text: ' ${recipe.difficulty!}'));
    }
    
    if (metadataItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: metadataItems,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build collapsible equipment section for side-by-side mode
  Widget _buildCollapsibleEquipment(ModernistRecipe recipe, ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _equipmentExpanded = !_equipmentExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _equipmentExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Equipment',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_equipmentExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                children: recipe.equipment.map((item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, ModernistRecipe recipe, ThemeData theme) {
    return [
      IconButton(
        icon: Icon(
          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: recipe.isFavorite ? theme.colorScheme.primary : null,
        ),
        onPressed: () async {
          await ref.read(modernistRepositoryProvider).toggleFavorite(recipe.id);
          ref.invalidate(modernistRecipeProvider(widget.recipeId));
        },
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_outline),
        tooltip: 'I made this',
        onPressed: () {
          ref.read(modernistRepositoryProvider).incrementCookCount(recipe.id);
          ref.invalidate(modernistRecipeProvider(widget.recipeId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logged cook for ${recipe.name}!')),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareRecipe(context, recipe),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(value, recipe),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
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

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, ModernistRecipe recipe) {
    final isDark = theme.brightness == Brightness.dark;
    // Use headerImage for the app bar, fall back to legacy imageUrl
    final headerImage = recipe.headerImage ?? recipe.imageUrl;
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final hasHeaderImage = showHeaderImages && headerImage != null && headerImage.isNotEmpty;
    final hasStepImages = recipe.stepImages.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with header image
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.name,
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
                        _buildSingleImage(headerImage),
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
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.primary : null,
                ),
                onPressed: () async {
                  await ref.read(modernistRepositoryProvider).toggleFavorite(recipe.id);
                  ref.invalidate(modernistRecipeProvider(widget.recipeId));
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'I made this',
                onPressed: () {
                  ref.read(modernistRepositoryProvider).incrementCookCount(recipe.id);
                  ref.invalidate(modernistRecipeProvider(widget.recipeId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged cook for ${recipe.name}!')),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, recipe),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
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

          // Recipe metadata - chips like Mains
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags row (same style as Mains)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category chip (Concept/Technique)
                      Chip(
                        label: Text(recipe.type.displayName),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        visualDensity: VisualDensity.compact,
                      ),
                      // Technique category if set
                      if (recipe.technique != null && recipe.technique!.isNotEmpty)
                        Chip(
                          label: Text(recipe.technique!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.serves != null && recipe.serves!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.people, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.serves!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.time != null && recipe.time!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.time!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),

                  // Special Equipment (simple list style, no banner)
                  if (recipe.equipment.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Special Equipment',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: recipe.equipment.map((item) => Chip(
                        label: Text(item),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        visualDensity: VisualDensity.compact,
                      ),).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Ingredients and Directions - always stacked in standard mode
          // (Side-by-side mode is handled at the screen level for proper scrolling)
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // On very wide screens (>800px), use side-by-side
                final useWideLayout = constraints.maxWidth > 800;
                
                if (useWideLayout) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ingredients', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  _buildIngredientsList(theme, recipe.ingredients),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Directions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  _buildDirectionsList(theme, recipe),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Stacked layout for standard view
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Ingredients',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildIngredientsList(theme, recipe.ingredients),
                      const SizedBox(height: 24),
                      Text(
                        'Directions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDirectionsList(theme, recipe),
                    ],
                  ),
                );
              },
            ),
          ),

          // Step Images Gallery (under directions, before comments)
          if (hasStepImages)
            SliverToBoxAdapter(
              key: _stepImagesKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildStepImagesGallery(theme, recipe),
              ),
            ),

          // Comments section (at bottom, after recipe content) - matches Mains "Comments"
          if (recipe.notes != null && recipe.notes!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Comments',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(recipe.notes!),
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

  /// Group ingredients by section
  Map<String, List<_IndexedIngredient>> _groupBySection(List<ModernistIngredient> ingredients) {
    final grouped = <String, List<_IndexedIngredient>>{};
    
    for (var i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      final section = ingredient.section ?? '';
      grouped.putIfAbsent(section, () => []);
      grouped[section]!.add(_IndexedIngredient(i, ingredient));
    }
    
    return grouped;
  }

  Widget _buildIngredientsList(ThemeData theme, List<ModernistIngredient> ingredients) {
    if (ingredients.isEmpty) {
      return const Text(
        'No ingredients listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    // Group by section if available
    final grouped = _groupBySection(ingredients);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final section = entry.key;
        final items = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            if (section.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  section,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            // Ingredients in this section
            ...items.map((item) => _buildIngredientRow(theme, item)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildIngredientRow(ThemeData theme, _IndexedIngredient item) {
    final index = item.index;
    final ingredient = item.ingredient;
    final isChecked = _checkedIngredients.contains(index);

    return InkWell(
      onTap: () {
        setState(() {
          if (isChecked) {
            _checkedIngredients.remove(index);
          } else {
            _checkedIngredients.add(index);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _checkedIngredients.add(index);
                    } else {
                      _checkedIngredients.remove(index);
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),

            // Main content - wrapped in Expanded to prevent overflow
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Ingredient name
                  Text(
                    ingredient.name,
                    style: TextStyle(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Amount
                  if (ingredient.displayText != ingredient.name)
                    Text(
                      ingredient.displayText.replaceFirst(ingredient.name, '').trim(),
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                  // Notes
                  if (ingredient.notes != null && ingredient.notes!.isNotEmpty)
                    Text(
                      ingredient.notes!,
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsList(ThemeData theme, ModernistRecipe recipe) {
    final directions = recipe.directions;
    if (directions.isEmpty) {
      return const Text(
        'No directions listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: directions.asMap().entries.map((entry) {
        final index = entry.key;
        final direction = entry.value;
        final isCompleted = _completedDirections.contains(index);
        final hasImage = recipe.getStepImageIndex(index) != null;

        return InkWell(
          onTap: () => setState(() {
            if (isCompleted) {
              _completedDirections.remove(index);
            } else {
              _completedDirections.add(index);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.secondary.withOpacity(0.2)
                        : theme.colorScheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.secondary)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    direction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                // Image icon if step has an image
                if (hasImage)
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'View step image',
                    onPressed: () => _scrollToAndShowImage(recipe, index),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepImagesGallery(ThemeData theme, ModernistRecipe recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Step Images',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recipe.stepImages.length,
                itemBuilder: (context, imageIndex) {
                  // Find which step(s) use this image
                  final stepsUsingImage = <int>[];
                  for (int i = 0; i < recipe.directions.length; i++) {
                    if (recipe.getStepImageIndex(i) == imageIndex) {
                      stepsUsingImage.add(i + 1);
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(left: imageIndex == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => _showImageFullscreen(recipe.stepImages[imageIndex]),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(recipe.stepImages[imageIndex], width: 120, height: 120),
                          ),
                          // Step numbers badge
                          if (stepsUsingImage.isNotEmpty)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  stepsUsingImage.map((s) => 'Step $s').join(', '),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          // Expand icon
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, {double? width, double? height}) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    }
  }

  void _scrollToAndShowImage(ModernistRecipe recipe, int stepIndex) {
    final imageIndex = recipe.getStepImageIndex(stepIndex);
    if (imageIndex == null || imageIndex >= recipe.stepImages.length) return;

    // Scroll to the step images section
    final context = _stepImagesKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ).then((_) {
        // After scrolling, show the image fullscreen
        _showImageFullscreen(recipe.stepImages[imageIndex]);
      });
    } else {
      // If context not found, just show the image
      _showImageFullscreen(recipe.stepImages[imageIndex]);
    }
  }

  void _showImageFullscreen(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark background
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.black.withOpacity(0.9)),
            ),
            // Image
            Center(
              child: InteractiveViewer(
                child: imagePath.startsWith('http')
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleImage(String source) {
    final isLocal = !source.startsWith('http');
    return isLocal
        ? Image.file(File(source), fit: BoxFit.cover)
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
          );
  }

  void _duplicateRecipe(ModernistRecipe recipe) async {
    final repo = ref.read(modernistRepositoryProvider);
    final newRecipe = ModernistRecipe.create(
      uuid: '',  // Will be generated on save
      name: '${recipe.name} (Copy)',
      type: recipe.type,
      technique: recipe.technique,
      serves: recipe.serves,
      time: recipe.time,
      equipment: List.from(recipe.equipment),
      ingredients: recipe.ingredients.map((i) => 
        ModernistIngredient.create(
          name: i.name,
          amount: i.amount,
          unit: i.unit,
          notes: i.notes,
          section: i.section,
        ),
      ).toList(),
      directions: List.from(recipe.directions),
      notes: recipe.notes,
      scienceNotes: recipe.scienceNotes,
      source: ModernistSource.personal,
      headerImage: recipe.headerImage,
      stepImages: List.from(recipe.stepImages),
      stepImageMap: List.from(recipe.stepImageMap),
    );
    
    await repo.save(newRecipe);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${newRecipe.name}')),
      );
    }
  }

  void _handleMenuAction(String action, ModernistRecipe recipe) async {
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernistEditScreen(recipeId: recipe.id),
          ),
        );
        ref.invalidate(modernistRecipeProvider(widget.recipeId));
        break;
      case 'duplicate':
        _duplicateRecipe(recipe);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Recipe'),
            content: Text('Are you sure you want to delete "${recipe.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.secondary,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await ref.read(modernistRepositoryProvider).delete(recipe.id);
          Navigator.pop(context);
        }
        break;
    }
  }

  void _shareRecipe(BuildContext context, ModernistRecipe recipe) {
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
                'Share "${recipe.name}"',
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
                shareService.showModernistQrCode(context, recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareModernistRecipe(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyModernistShareLink(recipe);
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
                shareService.shareModernistAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Helper class for indexed ingredients
class _IndexedIngredient {
  final int index;
  final ModernistIngredient ingredient;

  _IndexedIngredient(this.index, this.ingredient);
}
