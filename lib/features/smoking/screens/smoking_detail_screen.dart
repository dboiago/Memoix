import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';
import '../widgets/split_smoking_view.dart';
import '../../sharing/services/share_service.dart';
import '../../settings/screens/settings_screen.dart';
import 'smoking_edit_screen.dart';

/// Detail screen showing a smoking recipe's full information
class SmokingDetailScreen extends ConsumerWidget {
  final String recipeId;

  const SmokingDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(smokingRecipeByUuidProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recipe) {
          if (recipe == null) {
            return const Center(child: Text('Recipe not found'));
          }

          return _SmokingDetailView(recipe: recipe);
        },
      ),
    );
  }
}

class _SmokingDetailView extends ConsumerStatefulWidget {
  final SmokingRecipe recipe;

  const _SmokingDetailView({required this.recipe});

  @override
  ConsumerState<_SmokingDetailView> createState() => _SmokingDetailViewState();
}

class _SmokingDetailViewState extends ConsumerState<_SmokingDetailView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stepImagesKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useSideBySide = ref.watch(useSideBySideProvider);
    final recipe = widget.recipe;
    final theme = Theme.of(context);
    
    // Use side-by-side layout when enabled
    if (useSideBySide && recipe.directions.isNotEmpty) {
      return _buildSideBySideLayout(context, theme, recipe);
    }
    
    return _buildStandardLayout(context, theme, recipe);
  }

  Widget _buildSideBySideLayout(BuildContext context, ThemeData theme, SmokingRecipe recipe) {
    final hasStepImages = recipe.stepImages.isNotEmpty;
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final headerImage = recipe.headerImage ?? recipe.imageUrl;
    final hasHeaderImage = showHeaderImages && headerImage != null && headerImage.isNotEmpty;
    final headerColor = hasHeaderImage ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface;

    return Scaffold(
      body: Column(
        children: [
          // Rich Fixed Header
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              image: hasHeaderImage
                  ? DecorationImage(
                      image: NetworkImage(headerImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Gradient overlay for image legibility
                if (hasHeaderImage)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black26, Colors.black54],
                        ),
                      ),
                    ),
                  ),
                // SafeArea inside so background bleeds behind status bar
                SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: Back button + action icons
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: headerColor),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          ..._buildRichHeaderActions(context, recipe, theme, headerColor),
                        ],
                      ),
                      // Row 2: Recipe title (wraps to 2 lines max)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          recipe.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: headerColor,
                            shadows: hasHeaderImage
                                ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Compact metadata row
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                        child: _buildCompactMetadataRow(recipe, theme, overrideColor: hasHeaderImage ? theme.colorScheme.onSurfaceVariant : null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SplitSmokingView(
              recipe: recipe,
              onScrollToImage: hasStepImages ? (stepIndex) => _scrollToAndShowImage(recipe, stepIndex) : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action icons for the rich header
  List<Widget> _buildRichHeaderActions(BuildContext context, SmokingRecipe recipe, ThemeData theme, Color iconColor) {
    return [
      IconButton(
        icon: Icon(
          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: recipe.isFavorite ? theme.colorScheme.secondary : iconColor,
        ),
        onPressed: () async {
          await ref.read(smokingRepositoryProvider).toggleFavorite(recipe.uuid);
          ref.invalidate(allSmokingRecipesProvider);
        },
      ),
      IconButton(
        icon: Icon(Icons.check_circle_outline, color: iconColor),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(smokingRepositoryProvider).incrementCookCount(recipe.uuid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged cook for ${recipe.name}!')),
            );
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.share, color: iconColor),
        onPressed: () => _shareRecipe(context, ref, recipe),
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _editRecipe(context, recipe);
              break;
            case 'duplicate':
              _duplicateRecipe(context, ref, recipe);
              break;
            case 'delete':
              _confirmDelete(context, ref, recipe);
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.secondary)),
          ),
        ],
        icon: Icon(Icons.more_vert, color: iconColor),
      ),
    ];
  }

  /// Build compact metadata row for side-by-side mode
  Widget _buildCompactMetadataRow(SmokingRecipe recipe, ThemeData theme, {Color? overrideColor}) {
    final metadataItems = <InlineSpan>[];
    final textColor = overrideColor ?? theme.colorScheme.onSurfaceVariant;
    final iconColor = overrideColor ?? theme.colorScheme.onSurfaceVariant;
    
    // Add category with colored dot
    if (recipe.category != null && recipe.category!.isNotEmpty) {
      final categoryColor = MemoixColors.forSmokedItemDot(recipe.category);
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: categoryColor,
            shape: BoxShape.circle,
          ),
        ),
      ));
      metadataItems.add(TextSpan(text: recipe.category!));
    }
    
    // Add wood type
    if (recipe.wood.isNotEmpty) {
      if (metadataItems.isNotEmpty) {
        metadataItems.add(const TextSpan(text: '   '));
      }
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.park_outlined, size: 12, color: iconColor),
      ));
      metadataItems.add(TextSpan(text: ' ${recipe.wood}'));
    }
    
    // Add temperature (normalized with degree symbol)
    if (recipe.temperature.isNotEmpty) {
      final normalizedTemp = UnitNormalizer.normalizeTemperature(recipe.temperature);
      if (metadataItems.isNotEmpty) {
        metadataItems.add(const TextSpan(text: '   '));
      }
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.thermostat_outlined, size: 12, color: iconColor),
      ));
      metadataItems.add(TextSpan(text: ' $normalizedTemp'));
    }
    
    // Add time
    if (recipe.time.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeTime(recipe.time);
      if (normalized.isNotEmpty) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.schedule, size: 12, color: iconColor),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }
    
    if (metadataItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
        ),
        children: metadataItems,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, SmokingRecipe recipe, ThemeData theme) {
    return [
      IconButton(
        icon: Icon(
          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: recipe.isFavorite ? theme.colorScheme.secondary : null,
        ),
        onPressed: () async {
          await ref.read(smokingRepositoryProvider).toggleFavorite(recipe.uuid);
          ref.invalidate(allSmokingRecipesProvider);
        },
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_outline),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(smokingRepositoryProvider).incrementCookCount(recipe.uuid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged cook for ${recipe.name}!')),
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareRecipe(context, ref, recipe),
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _editRecipe(context, recipe);
              break;
            case 'duplicate':
              _duplicateRecipe(context, ref, recipe);
              break;
            case 'delete':
              _confirmDelete(context, ref, recipe);
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.secondary)),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
    ];
  }

  Widget _buildStandardLayout(BuildContext context, ThemeData theme, SmokingRecipe recipe) {
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final isDark = theme.brightness == Brightness.dark;
    // Use headerImage for the app bar, fall back to legacy imageUrl
    final headerImage = recipe.headerImage ?? recipe.imageUrl;
    final hasHeaderImage = showHeaderImages && headerImage != null && headerImage.isNotEmpty;
    final hasStepImages = recipe.stepImages.isNotEmpty;
    return CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final expandRatio = (constraints.maxHeight - kToolbarHeight) /
                    ((hasHeaderImage ? 250 : 120) - kToolbarHeight);
                final clampedRatio = expandRatio.clamp(0.0, 1.0);
                final screenWidth = MediaQuery.sizeOf(context).width;
                // Expanded: 20-28pt, Collapsed: 18-24pt (interpolated by clampedRatio)
                final expandedFontSize = (screenWidth / 40).clamp(20.0, 28.0);
                final collapsedFontSize = (screenWidth / 50).clamp(18.0, 24.0);
                final fontSize = collapsedFontSize + (clampedRatio * (expandedFontSize - collapsedFontSize));
                
                return FlexibleSpaceBar(
                  title: Text(
                    recipe.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                      color: hasHeaderImage && clampedRatio > 0.3 
                          ? theme.colorScheme.onSurfaceVariant 
                          : theme.colorScheme.onSurface,
                      shadows: hasHeaderImage && clampedRatio > 0.3
                          ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 16,
                    end: 160,
                  ),
                  background: hasHeaderImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildSingleImage(context, headerImage),
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
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.secondary : null,
                ),
                onPressed: () async {
                  await ref.read(smokingRepositoryProvider).toggleFavorite(recipe.uuid);
                  ref.invalidate(allSmokingRecipesProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'I made this',
                onPressed: () async {
                  await ref.read(smokingRepositoryProvider).incrementCookCount(recipe.uuid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logged cook for ${recipe.name}!'),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareRecipe(context, ref, recipe),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editRecipe(context, recipe);
                      break;
                    case 'duplicate':
                      _duplicateRecipe(context, ref, recipe);
                      break;
                    case 'delete':
                      _confirmDelete(context, ref, recipe);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
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
            ],
          ),

              // Recipe details - styled like regular recipe page
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick info chips (category, temperature, time, wood)
                      _buildQuickInfo(context, recipe),
                    ],
                  ),
                ),
              ),
              
              // Ingredients and Directions - always stacked in standard mode
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // On very wide screens (>800px), use side-by-side
                    final useWideLayout = constraints.maxWidth > 800;
                    
                    if (useWideLayout) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      _buildIngredientsContent(theme, recipe),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (recipe.directions.isNotEmpty)
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
                                        _buildDirectionsList(context, recipe),
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
                          _buildIngredientsContent(theme, recipe),
                          const SizedBox(height: 24),
                          if (recipe.directions.isNotEmpty) ...[
                            Text(
                              'Directions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDirectionsList(context, recipe),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Step Images Gallery (under directions, before notes)
              if (hasStepImages)
                SliverToBoxAdapter(
                  key: _stepImagesKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _buildStepImagesGallery(theme, recipe),
                  ),
                ),

              // Notes section (if present)
              if (recipe.notes != null && recipe.notes!.isNotEmpty)
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
                              recipe.notes!,
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
          );
  }
  
  /// Build an ingredient section with header and checkable list
  Widget _buildIngredientSection(ThemeData theme, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        // Ingredient list
        _SmokingIngredientList(items: items),
      ],
    );
  }

  Widget _buildQuickInfo(BuildContext context, SmokingRecipe recipe) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Category with colored dot (not item) - shown for both types
        if (recipe.category != null)
          Chip(
            avatar: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: MemoixColors.forSmokedItemDot(recipe.category),
                shape: BoxShape.circle,
              ),
            ),
            label: Text(recipe.category!),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface),
            visualDensity: VisualDensity.compact,
          ),
        
        // Pit Note specific: Temperature, Time (required), Wood
        if (recipe.type == SmokingType.pitNote) ...[
          // Temperature (normalized with degree symbol)
          if (recipe.temperature.isNotEmpty)
            Chip(
              avatar: Icon(Icons.thermostat, size: 16, color: theme.colorScheme.onSurface),
              label: Text(UnitNormalizer.normalizeTemperature(recipe.temperature)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(color: theme.colorScheme.onSurface),
              visualDensity: VisualDensity.compact,
            ),
          // Time (normalized)
          if (recipe.time.isNotEmpty)
            Chip(
              avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
              label: Text(UnitNormalizer.normalizeTime(recipe.time)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(color: theme.colorScheme.onSurface),
              visualDensity: VisualDensity.compact,
            ),
          // Wood
          if (recipe.wood.isNotEmpty)
            Chip(
              avatar: Icon(Icons.park, size: 16, color: theme.colorScheme.onSurface),
              label: Text(recipe.wood),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(color: theme.colorScheme.onSurface),
              visualDensity: VisualDensity.compact,
            ),
        ],
        
        // Recipe type: Serves, Time (optional)
        if (recipe.type == SmokingType.recipe) ...[
          if (recipe.serves != null && recipe.serves!.isNotEmpty)
            Chip(
              avatar: Icon(Icons.people_outline, size: 16, color: theme.colorScheme.onSurface),
              label: Text(UnitNormalizer.normalizeServes(recipe.serves!)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(color: theme.colorScheme.onSurface),
              visualDensity: VisualDensity.compact,
            ),
          if (recipe.time.isNotEmpty)
            Chip(
              avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
              label: Text(UnitNormalizer.normalizeTime(recipe.time)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(color: theme.colorScheme.onSurface),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ],
    );
  }

  /// Build ingredients content based on recipe type
  Widget _buildIngredientsContent(ThemeData theme, SmokingRecipe recipe) {
    if (recipe.type == SmokingType.pitNote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main item section
          if (recipe.item != null && recipe.item!.isNotEmpty) ...
            [
              _buildIngredientSection(theme, 'Main', [recipe.item!]),
            ],
          // Seasonings section
          if (recipe.seasonings.isNotEmpty) ...[
            if (recipe.item != null && recipe.item!.isNotEmpty)
              const SizedBox(height: 16),
            _buildIngredientSection(
              theme,
              recipe.seasonings.length == 1 ? 'Seasoning' : 'Seasonings',
              recipe.seasonings.map((s) => s.displayText).toList(),
            ),
          ],
        ],
      );
    }
    
    // For Recipe type: show full ingredients list with checkboxes
    if (recipe.ingredients.isEmpty) {
      return Text(
        'No ingredients',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    
    return _SmokingIngredientsList(ingredients: recipe.ingredients);
  }

  Widget _buildDirectionsList(BuildContext context, SmokingRecipe recipe) {
    final theme = Theme.of(context);

    return Column(
      children: recipe.directions.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final hasStepImage = recipe.getStepImageIndex(index) != null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number with outlined secondary styling
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    step,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              // Step image indicator
              if (hasStepImage)
                IconButton(
                  icon: Icon(
                    Icons.image,
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
        );
      }).toList(),
    );
  }

  Widget _buildSingleImage(BuildContext context, String imageSource) {
    final isLocalFile = !imageSource.startsWith('http');
    return isLocalFile
        ? Image.file(
            File(imageSource),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          )
        : Image.network(
            imageSource,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          );
  }

  Widget _buildStepImagesGallery(ThemeData theme, SmokingRecipe recipe) {
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
                            child: _buildStepImageWidget(recipe.stepImages[imageIndex], width: 120, height: 120),
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

  Widget _buildStepImageWidget(String imagePath, {double? width, double? height}) {
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

  void _scrollToAndShowImage(SmokingRecipe recipe, int stepIndex) {
    final imageIndex = recipe.getStepImageIndex(stepIndex);
    if (imageIndex == null || imageIndex >= recipe.stepImages.length) return;

    // Scroll to the step images section
    final ctx = _stepImagesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
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

  void _editRecipe(BuildContext context, SmokingRecipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmokingEditScreen(recipeId: recipe.uuid),
      ),
    );
  }

  void _duplicateRecipe(BuildContext context, WidgetRef ref, SmokingRecipe recipe) async {
    final repo = ref.read(smokingRepositoryProvider);
    final newUuid = const Uuid().v4();
    
    final newRecipe = SmokingRecipe.create(
      uuid: newUuid,
      name: '${recipe.name} (Copy)',
      type: recipe.type,
      item: recipe.item,
      category: recipe.category,
      temperature: recipe.temperature,
      time: recipe.time,
      wood: recipe.wood,
      seasonings: recipe.seasonings.map((s) => SmokingSeasoning.create(
        name: s.name,
        amount: s.amount,
        unit: s.unit,
      )).toList(),
      ingredients: recipe.ingredients.map((i) => SmokingSeasoning.create(
        name: i.name,
        amount: i.amount,
        unit: i.unit,
      )).toList(),
      serves: recipe.serves,
      directions: List.from(recipe.directions),
      notes: recipe.notes,
      source: SmokingSource.personal,
    );
    
    await repo.saveRecipe(newRecipe);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${newRecipe.name}')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SmokingRecipe recipe,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(smokingRepositoryProvider).deleteRecipe(recipe.uuid);
      Navigator.pop(context);
    }
  }

  void _shareRecipe(BuildContext context, WidgetRef ref, SmokingRecipe recipe) {
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
                shareService.showSmokingQrCode(context, recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareSmokingRecipe(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copySmokingShareLink(recipe);
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
                shareService.shareSmokingAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Stateful ingredient list with checkboxes for smoking recipes
class _SmokingIngredientList extends StatefulWidget {
  final List<String> items;

  const _SmokingIngredientList({required this.items});

  @override
  State<_SmokingIngredientList> createState() => _SmokingIngredientListState();
}

class _SmokingIngredientListState extends State<_SmokingIngredientList> {
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyLarge?.copyWith(
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
/// Stateful widget for smoking ingredients with checkboxes
class _SmokingIngredientsList extends StatefulWidget {
  final List<SmokingSeasoning> ingredients;
  
  const _SmokingIngredientsList({required this.ingredients});
  
  @override
  State<_SmokingIngredientsList> createState() => _SmokingIngredientsListState();
}

class _SmokingIngredientsListState extends State<_SmokingIngredientsList> {
  final Set<int> _checkedItems = {};
  
  /// Capitalize the first letter of each word
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      final lower = word.toLowerCase();
      if (lower == 'of' || lower == 'and' || lower == 'or' || lower == 'the' || lower == 'a' || lower == 'an' || lower == 'to' || lower == 'for') {
        return lower;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  
  /// Format amount to clean up decimals
  String _formatAmount(String amount) {
    var result = amount.trim();
    // Remove trailing .0 from whole numbers
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\.0(?=\s|$|-|–)'),
      (match) => match.group(1)!,
    );
    if (result.endsWith('.0')) {
      result = result.substring(0, result.length - 2);
    }
    return result;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ingredient = entry.value;
        final isChecked = _checkedItems.contains(index);
        
        // Build amount string
        String amountText = '';
        if (ingredient.amount != null && ingredient.amount!.isNotEmpty) {
          amountText = _formatAmount(ingredient.amount!);
          if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
            amountText += ' ${ingredient.unit}';
          }
        }
        
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredient name
                      Text(
                        _capitalizeWords(ingredient.name),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : null,
                        ),
                      ),
                      // Amount
                      if (amountText.isNotEmpty)
                        Text(
                          amountText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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