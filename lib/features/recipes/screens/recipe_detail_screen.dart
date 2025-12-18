import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/category.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/direction_list.dart';
import '../widgets/split_recipe_view.dart';
import '../../sharing/services/share_service.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../settings/screens/settings_screen.dart';

/// Format serves to just show the number (e.g., "6 people" -> "6", "Serves 4" -> "4")
String _formatServes(String serves) {
  // First strip common words
  var result = serves
      .replaceAll(RegExp(r'\bserves?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bpeople\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bpersons?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bportions?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bservings?\b', caseSensitive: false), '')
      .trim();
  
  // Remove .0 decimals
  result = result.replaceAllMapped(
    RegExp(r'(\d+)\.0(?=\D|$)'),
    (match) => match.group(1)!,
  );
  
  return result.trim();
}

/// Get the Material icon for a course category slug
IconData _iconForCourse(String course) {
  switch (course.toLowerCase()) {
    case 'apps':
      return Icons.restaurant;
    case 'soup':
    case 'soups':
      return Icons.soup_kitchen;
    case 'mains':
      return Icons.dinner_dining;
    case 'vegn':
      return Icons.eco;
    case 'sides':
      return Icons.rice_bowl;
    case 'salad':
    case 'salads':
      return Icons.grass;
    case 'desserts':
      return Icons.cake;
    case 'brunch':
      return Icons.egg_alt;
    case 'drinks':
      return Icons.local_bar;
    case 'breads':
      return Icons.bakery_dining;
    case 'sauces':
      return Icons.water_drop;
    case 'rubs':
      return Icons.local_fire_department;
    case 'pickles':
      return Icons.local_florist;
    case 'modernist':
      return Icons.science;
    case 'pizzas':
      return Icons.local_pizza;
    case 'sandwiches':
      return Icons.lunch_dining;
    case 'smoking':
      return Icons.outdoor_grill;
    case 'cheese':
      return Icons.lunch_dining;
    case 'scratch':
      return Icons.note_alt;
    default:
      return Icons.restaurant_menu;
  }
}

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the recipes stream to get live updates on favourite changes
    final recipesAsync = ref.watch(allRecipesProvider);

    return recipesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (recipes) {
        final recipe = recipes.firstWhere(
          (r) => r.uuid == recipeId,
          orElse: () => Recipe()..name = '',
        );
        
        if (recipe.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        return RecipeDetailView(recipe: recipe);
      },
    );
  }
}

class RecipeDetailView extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends ConsumerState<RecipeDetailView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stepImagesKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    // Enable wakelock if setting is on
    final keepScreenOn = ref.watch(keepScreenOnProvider);
    if (keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Use headerImage for the app bar, fall back to legacy imageUrl/imageUrls
    final headerImage = recipe.headerImage ?? recipe.getFirstImage();
    // Check if header images should be shown (user setting)
    final showHeaderImages = ref.watch(showHeaderImagesProvider);
    final hasHeaderImage = showHeaderImages && headerImage != null && headerImage.isNotEmpty;
    final hasStepImages = recipe.stepImages.isNotEmpty;
    
    // Check if side-by-side mode is enabled
    final useSideBySide = ref.watch(useSideBySideProvider);
    
    if (useSideBySide) {
      return _buildSideBySideLayout(context, recipe, theme, hasHeaderImage, headerImage, hasStepImages);
    }
    
    return _buildStandardLayout(context, recipe, theme, hasHeaderImage, headerImage, hasStepImages);
  }

  /// Build the side-by-side layout with independent scrolling columns
  Widget _buildSideBySideLayout(
    BuildContext context,
    Recipe recipe,
    ThemeData theme,
    bool hasHeaderImage,
    String? headerImage,
    bool hasStepImages,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Scale font size with screen width: 18px at 320, up to 28px at 1200+
    final baseFontSize = (screenWidth / 50).clamp(18.0, 28.0);
    
    // Calculate header height: image (if any) + title container
    // Title container has padding (16) + title (variable) + spacing (4) + metadata (~20) + optional pairs (~30)
    final hasPairs = recipe.supportsPairing && _hasPairedRecipes(ref, recipe);
    final titleContainerHeight = hasPairs ? 90.0 : 60.0;
    final headerHeight = (hasHeaderImage ? 100.0 : 0.0) + titleContainerHeight;
    
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
                      _buildSingleImage(context, headerImage!),
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
              // Recipe title with dynamic sizing - uses surfaceContainerHighest like no-image mode
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title that shrinks to fit - calculate font size based on name length and width
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate appropriate font size based on text length and available width
                        // Longer names get smaller fonts
                        final nameLength = recipe.name.length;
                        final availableWidth = constraints.maxWidth;
                        
                        // Estimate: average char width is ~0.55 * fontSize
                        // So fontSize = availableWidth / (nameLength * 0.55)
                        // Clamp between reasonable min/max
                        final calculatedSize = (availableWidth / (nameLength * 0.55)).clamp(14.0, baseFontSize);
                        
                        return Text(
                          recipe.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: calculatedSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Compact metadata row with dots
                    _buildCompactMetadataRow(recipe, theme),
                    // Paired recipes chips (if any) - right-aligned
                    if (hasPairs)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: _buildPairedRecipeChips(context, ref, recipe, theme),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SplitRecipeView(
        recipe: recipe,
        onScrollToImage: hasStepImages ? (stepIndex) => _scrollToAndShowImage(recipe, stepIndex) : null,
      ),
    );
  }

  /// Build compact metadata with title for cockpit mode
  Widget _buildCompactMetadataWithTitle(BuildContext context, Recipe recipe, ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final chipFontSize = isCompact ? 11.0 : 12.0;
    
    // Calculate font size that fits the screen width
    // Start with base size and reduce if needed
    final baseFontSize = isCompact ? 18.0 : 22.0;
    final minFontSize = isCompact ? 14.0 : 16.0;
    
    // Get paired recipe chips if any exist
    final hasPairedRecipes = recipe.supportsPairing && _hasPairedRecipes(ref, recipe);
    final pairedChips = hasPairedRecipes 
        ? _buildPairedRecipeChips(context, ref, recipe, theme)
        : <Widget>[];
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe title - uses FittedBox to shrink text to fit
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                recipe.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: baseFontSize,
                ),
                maxLines: 2,
              ),
            ),
          ),
          // Main metadata chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (recipe.cuisine != null)
                Chip(
                  label: Text(Cuisine.toAdjective(recipe.cuisine)),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(fontSize: chipFontSize),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              if (recipe.serves != null && recipe.serves!.isNotEmpty)
                Chip(
                  avatar: Icon(Icons.people, size: 12, color: theme.colorScheme.onSurface),
                  label: Text(_formatServes(recipe.serves!)),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(fontSize: chipFontSize),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              if (recipe.time != null && recipe.time!.isNotEmpty)
                Chip(
                  avatar: Icon(Icons.timer, size: 12, color: theme.colorScheme.onSurface),
                  label: Text(recipe.time!),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(fontSize: chipFontSize),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          // "Pairs With" chips on a separate line, right-aligned
          if (pairedChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: pairedChips,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build compact metadata row with colored dots for side-by-side mode
  Widget _buildCompactMetadataRow(Recipe recipe, ThemeData theme) {
    final metadataItems = <InlineSpan>[];
    
    // Add cuisine with colored dot (using same method as recipe card)
    if (recipe.cuisine != null) {
      final cuisineColor = MemoixColors.forContinentDot(recipe.cuisine);
      metadataItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: cuisineColor,
            shape: BoxShape.circle,
          ),
        ),
      ));
      metadataItems.add(TextSpan(text: Cuisine.toAdjective(recipe.cuisine)));
    }
    
    // Add serves (normalized to just number with icon)
    if (recipe.serves != null && recipe.serves!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeServes(recipe.serves!);
      if (normalized.isNotEmpty) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.people, size: 12, color: theme.colorScheme.onSurfaceVariant),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }
    
    // Add time (normalized to compact format with icon)
    if (recipe.time != null && recipe.time!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeTime(recipe.time!);
      if (normalized.isNotEmpty) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.schedule, size: 12, color: theme.colorScheme.onSurfaceVariant),
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
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: metadataItems,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build app bar actions (shared between layouts)
  List<Widget> _buildAppBarActions(BuildContext context, Recipe recipe, ThemeData theme) {
    return [
      IconButton(
        icon: Icon(
          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: recipe.isFavorite ? theme.colorScheme.primary : null,
        ),
        onPressed: () async {
          await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
          ref.invalidate(allRecipesProvider);
        },
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_outline),
        tooltip: 'I made this',
        onPressed: () async {
          await ref.read(cookingStatsServiceProvider).logCook(
            recipeId: recipe.uuid,
            recipeName: recipe.name,
            course: recipe.course,
            cuisine: recipe.cuisine,
          );
          ref.invalidate(cookingStatsProvider);
          ref.invalidate(recipeCookCountProvider(recipe.uuid));
          ref.invalidate(recipeLastCookProvider(recipe.uuid));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Logged cook for ${recipe.name}!'),
                action: SnackBarAction(
                  label: 'Stats',
                  onPressed: () => AppRoutes.toStatistics(context),
                ),
              ),
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareRecipe(context, ref),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, value),
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

  /// Build the standard layout (existing behavior)
  Widget _buildStandardLayout(
    BuildContext context,
    Recipe recipe,
    ThemeData theme,
    bool hasHeaderImage,
    String? headerImage,
    bool hasStepImages,
  ) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero header with recipe image or colored header
          SliverAppBar(
            expandedHeight: hasHeaderImage ? 250 : 120,
            collapsedHeight: 80, // Space for title below toolbar
            pinned: true,
            // Title area at the bottom that stays on its own line
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                // Calculate how collapsed we are (0 = fully expanded, 1 = fully collapsed)
                final maxExtent = hasHeaderImage ? 250.0 : 120.0;
                final statusBarHeight = MediaQuery.of(context).padding.top;
                final minExtent = 80.0 + statusBarHeight;
                final currentExtent = constraints.maxHeight;
                final collapseRatio = ((maxExtent - currentExtent) / (maxExtent - minExtent)).clamp(0.0, 1.0);
                
                // Calculate font size based on name length and available width
                final availableWidth = screenWidth - 32;
                final nameLength = recipe.name.length;
                // Base font sizes that scale with screen
                final baseExpandedSize = (screenWidth / 25).clamp(24.0, 40.0);
                final baseCollapsedSize = (screenWidth / 35).clamp(18.0, 28.0);
                // Adjust for name length - longer names get smaller fonts
                final lengthFactor = (30 / nameLength).clamp(0.5, 1.0);
                final expandedFontSize = baseExpandedSize * lengthFactor;
                final collapsedFontSize = baseCollapsedSize * lengthFactor;
                // Interpolate based on collapse
                final fontSize = expandedFontSize - (expandedFontSize - collapsedFontSize) * collapseRatio;
                
                final titleColor = hasHeaderImage || collapseRatio < 0.7 
                    ? Colors.white 
                    : theme.colorScheme.onSurface;
                
                return FlexibleSpaceBar(
                  titlePadding: EdgeInsets.zero,
                  title: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      top: 8,
                    ),
                    decoration: hasHeaderImage && collapseRatio < 0.7
                        ? null
                        : BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                    child: Text(
                      recipe.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize.clamp(14.0, 40.0),
                        color: titleColor,
                        shadows: hasHeaderImage && collapseRatio < 0.7
                            ? [const Shadow(blurRadius: 4, color: Colors.black54)]
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: hasHeaderImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildSingleImage(context, headerImage!),
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
                  color: recipe.isFavorite ? theme.colorScheme.primary : null,
                ),
                onPressed: () async {
                  await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
                  ref.invalidate(allRecipesProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'I made this',
                onPressed: () async {
                  await ref.read(cookingStatsServiceProvider).logCook(
                    recipeId: recipe.uuid,
                    recipeName: recipe.name,
                    course: recipe.course,
                    cuisine: recipe.cuisine,
                  );
                  // Invalidate stats providers so they refresh
                  ref.invalidate(cookingStatsProvider);
                  ref.invalidate(recipeCookCountProvider(recipe.uuid));
                  ref.invalidate(recipeLastCookProvider(recipe.uuid));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logged cook for ${recipe.name}!'),
                        action: SnackBarAction(
                          label: 'Stats',
                          onPressed: () => AppRoutes.toStatistics(context),
                        ),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareRecipe(context, ref),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
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

          // Recipe metadata
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta chips row (Cuisine, Pickle Method, Serves, Time, Nutrition)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (recipe.cuisine != null)
                        Chip(
                          label: Text(Cuisine.toAdjective(recipe.cuisine)),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      // Pickle method chip
                      if (recipe.course == 'pickles' && recipe.pickleMethod != null && recipe.pickleMethod!.isNotEmpty)
                        Chip(
                          label: Text(recipe.pickleMethod!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.serves != null && recipe.serves!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.people, size: MediaQuery.of(context).size.width < 600 ? 14 : 16, color: theme.colorScheme.onSurface),
                          label: Text(_formatServes(recipe.serves!)),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.time != null && recipe.time!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.timer, size: MediaQuery.of(context).size.width < 600 ? 14 : 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.time!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.nutrition != null && recipe.nutrition!.hasData)
                        Tooltip(
                          message: _buildNutritionTooltip(recipe.nutrition!),
                          child: ActionChip(
                            avatar: Icon(Icons.local_fire_department, size: MediaQuery.of(context).size.width < 600 ? 14 : 16, color: theme.colorScheme.onSurface),
                            label: Text(recipe.nutrition!.compactDisplay ?? 'Nutrition'),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showNutritionDialog(context, recipe.nutrition!),
                          ),
                        ),
                    ],
                  ),
                  // Paired recipe chips on their own row, right-aligned
                  if (recipe.supportsPairing && _hasPairedRecipes(ref, recipe))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: _buildPairedRecipeChips(context, ref, recipe, theme),
                        ),
                      ),
                    ),

                  // Glass and Garnish (for Drinks) - side by side
                  if (recipe.course == 'drinks' && 
                      ((recipe.glass != null && recipe.glass!.isNotEmpty) || recipe.garnish.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Glass
                        if (recipe.glass != null && recipe.glass!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Glass',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(recipe.glass!),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        if (recipe.glass != null && recipe.glass!.isNotEmpty && recipe.garnish.isNotEmpty)
                          const SizedBox(width: 24),
                        // Garnish
                        if (recipe.garnish.isNotEmpty)
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Garnish',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: recipe.garnish.map((item) => Chip(
                                    label: Text(item),
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Ingredients and Directions - always stacked in standard mode
          // (Side-by-side mode uses _buildSideBySideLayout instead)
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // On very wide screens (>800px), use side-by-side even in standard mode
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
                                  IngredientList(ingredients: recipe.ingredients),
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
                                  DirectionList(
                                    directions: recipe.directions,
                                    recipe: recipe,
                                    onScrollToImage: (stepIndex) => _scrollToAndShowImage(recipe, stepIndex),
                                  ),
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
                      IngredientList(ingredients: recipe.ingredients),
                      const SizedBox(height: 24),
                      Text(
                        'Directions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DirectionList(
                        directions: recipe.directions,
                        recipe: recipe,
                        onScrollToImage: (stepIndex) => _scrollToAndShowImage(recipe, stepIndex),
                      ),
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

          // Comments section (at bottom, after recipe content)
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
                            Icon(Icons.comment, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Comments',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

          // Source URL
          if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Original Recipe'),
                  onPressed: () async {
                    final url = Uri.tryParse(recipe.sourceUrl!);
                    if (url != null && await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
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

  Widget _buildStepImagesGallery(ThemeData theme, Recipe recipe) {
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

  void _scrollToAndShowImage(Recipe recipe, int stepIndex) {
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

  /// Check if a recipe has any paired recipes (explicit or inverse)
  bool _hasPairedRecipes(WidgetRef ref, Recipe recipe) {
    final allRecipesAsync = ref.watch(allRecipesProvider);
    final allRecipes = allRecipesAsync.valueOrNull ?? [];
    
    if (allRecipes.isEmpty) return false;
    
    // Check for explicit pairings
    if (recipe.pairedRecipeIds.isNotEmpty) return true;
    
    // Check for inverse pairings
    for (final r in allRecipes) {
      if (r.pairedRecipeIds.contains(recipe.uuid)) return true;
    }
    
    return false;
  }

  /// Build paired recipe chips showing both explicit and inverse pairings.
  /// Explicit: recipes this recipe links to (via pairedRecipeIds).
  /// Inverse: recipes that link to this recipe (via their pairedRecipeIds).
  List<Widget> _buildPairedRecipeChips(
    BuildContext context, 
    WidgetRef ref, 
    Recipe recipe, 
    ThemeData theme,
  ) {
    final chips = <Widget>[];
    
    // Get all recipes for lookup
    final allRecipesAsync = ref.watch(allRecipesProvider);
    final allRecipes = allRecipesAsync.valueOrNull ?? [];
    
    if (allRecipes.isEmpty) return chips;
    
    // Collect all paired recipes (explicit + inverse)
    final pairedRecipes = <Recipe>[];
    
    // 1. Explicit pairings: recipes we link to
    for (final uuid in recipe.pairedRecipeIds) {
      final linked = allRecipes.where((r) => r.uuid == uuid).firstOrNull;
      if (linked != null && !pairedRecipes.any((r) => r.uuid == linked.uuid)) {
        pairedRecipes.add(linked);
      }
    }
    
    // 2. Inverse pairings: recipes that link to us
    for (final r in allRecipes) {
      if (r.pairedRecipeIds.contains(recipe.uuid) && 
          !pairedRecipes.any((pr) => pr.uuid == r.uuid)) {
        pairedRecipes.add(r);
      }
    }
    
    // Build chips for each paired recipe
    final isCompact = MediaQuery.of(context).size.width < 600;
    for (final paired in pairedRecipes) {
      chips.add(
        ActionChip(
          avatar: Icon(
            _iconForCourse(paired.course),
            size: isCompact ? 14 : 16,
            color: theme.colorScheme.onSurface,
          ),
          label: Text(paired.name),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: isCompact ? 12 : 14,
          ),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: paired.uuid),
              ),
            );
          },
        ),
      );
    }
    
    return chips;
  }

  void _shareRecipe(BuildContext context, WidgetRef ref) {
    final recipe = widget.recipe;
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
                shareService.showQrCode(context, recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareRecipe(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyShareLink(recipe);
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
                shareService.shareAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    final recipe = widget.recipe;
    switch (action) {
      case 'edit':
        AppRoutes.toRecipeEdit(context, recipeId: recipe.uuid);
        break;
      case 'duplicate':
        _duplicateRecipe(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _duplicateRecipe(BuildContext context, WidgetRef ref) async {
    final recipe = widget.recipe;
    final repo = ref.read(recipeRepositoryProvider);
    final newRecipe = Recipe()
      ..uuid = ''  // Will be generated on save
      ..name = '${recipe.name} (Copy)'
      ..course = recipe.course
      ..cuisine = recipe.cuisine
      ..serves = recipe.serves
      ..time = recipe.time
      ..pairsWith = List.from(recipe.pairsWith)
      ..notes = recipe.notes
      ..ingredients = recipe.ingredients.map((i) => 
        Ingredient()
          ..name = i.name
          ..amount = i.amount
          ..unit = i.unit
          ..preparation = i.preparation
          ..alternative = i.alternative
          ..isOptional = i.isOptional
          ..section = i.section,
      ).toList()
      ..directions = List.from(recipe.directions)
      ..source = RecipeSource.personal
      ..tags = List.from(recipe.tags);
    
    await repo.saveRecipe(newRecipe);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${newRecipe.name}')),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final recipe = widget.recipe;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.secondary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _buildNutritionTooltip(NutritionInfo nutrition) {
    final parts = <String>[];
    if (nutrition.calories != null) parts.add('${nutrition.calories} cal');
    if (nutrition.proteinContent != null) parts.add('${nutrition.proteinContent}g protein');
    if (nutrition.carbohydrateContent != null) parts.add('${nutrition.carbohydrateContent}g carbs');
    if (nutrition.fatContent != null) parts.add('${nutrition.fatContent}g fat');
    return parts.join(' • ');
  }

  void _showNutritionDialog(BuildContext context, NutritionInfo nutrition) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            const Text('Nutrition Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nutrition.servingSize != null)
              _nutritionRow('Serving Size', nutrition.servingSize!),
            if (nutrition.calories != null)
              _nutritionRow('Calories', '${nutrition.calories}'),
            if (nutrition.proteinContent != null)
              _nutritionRow('Protein', '${nutrition.proteinContent}g'),
            if (nutrition.carbohydrateContent != null)
              _nutritionRow('Carbohydrates', '${nutrition.carbohydrateContent}g'),
            if (nutrition.fiberContent != null)
              _nutritionRow('Fiber', '${nutrition.fiberContent}g'),
            if (nutrition.sugarContent != null)
              _nutritionRow('Sugar', '${nutrition.sugarContent}g'),
            if (nutrition.fatContent != null)
              _nutritionRow('Total Fat', '${nutrition.fatContent}g'),
            if (nutrition.saturatedFatContent != null)
              _nutritionRow('Saturated Fat', '${nutrition.saturatedFatContent}g'),
            if (nutrition.cholesterolContent != null)
              _nutritionRow('Cholesterol', '${nutrition.cholesterolContent}mg'),
            if (nutrition.sodiumContent != null)
              _nutritionRow('Sodium', '${nutrition.sodiumContent}mg'),
            const SizedBox(height: 16),
            Text(
              'Note: Nutrition information is estimated and may vary based on ingredients and preparation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _nutritionItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Build a single image display
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

  /// Build an image carousel for multiple images
  Widget _buildImageCarousel(List<String> images) {
    return _RecipeImageCarousel(images: images);
  }
}

/// Simple carousel widget for recipe images in the app bar
class _RecipeImageCarousel extends StatefulWidget {
  final List<String> images;

  const _RecipeImageCarousel({required this.images});

  @override
  State<_RecipeImageCarousel> createState() => _RecipeImageCarouselState();
}

class _RecipeImageCarouselState extends State<_RecipeImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final source = widget.images[index];
            final isLocalFile = !source.startsWith('http');
            return isLocalFile
                ? Image.file(
                    File(source),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade800,
                    ),
                  )
                : Image.network(
                    source,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade800,
                    ),
                  );
          },
        ),

        // Page indicator badge (top right)
        Positioned(
          top: 48,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPage + 1}/${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Page indicators (bottom)
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == _currentPage
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
