import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/routes/router.dart';
import '../../../core/utils/amount_utils.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../../shared/widgets/memoix_header.dart';
import '../../../shared/widgets/course_icon_widget.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/direction_list.dart';
import '../widgets/split_recipe_view.dart';
import '../../sharing/services/share_service.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/services/integrity_service.dart';
import '../../ai/ai_settings_provider.dart';
import '../widgets/ingredient_reference_sheet.dart';

bool shouldShowCompareButton(Recipe recipe) {
  final allowed = {
    'apps', 'appetizers', 'soups', 'mains', "veg'n", 'vegn', 'sides', 'salads',
    'desserts', 'brunch', 'breads', 'sauces', 'rubs', 'pickles',
  };
  final blocked = {
    'drinks', 'pizza', 'pizzas', 'sandwiches', 'cheese', 'cellar',
  };
  final course = recipe.course.toLowerCase();
  if (blocked.contains(course)) return false;
  if (allowed.contains(course)) {
    // Modernist: only allow if Concept
    if (course == 'modernist') {
      return recipe.modernistType?.toLowerCase() == 'concept';
    }
    // Smoking: only allow if Recipe
    if (course == 'smoking') {
      return recipe.smokingType?.toLowerCase() != 'pit note';
    }
    return true;
  }
  return false;
}

/// Capitalize the first letter of each word in a string
String _capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    // Don't capitalize common lowercase words in the middle
    if (lower == 'of' || lower == 'and' || lower == 'or' || lower == 'the' || lower == 'a' || lower == 'an' || lower == 'to' || lower == 'for' || lower == 'with') {
      return lower;
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the single recipe matching this screen's UUID so unrelated
    // recipe changes (other recipes' cookCount, nutrition, etc.) do not cause
    // this screen to rebuild.
    final recipesAsync = ref.watch(
      allRecipesProvider.select(
        (v) => v.whenData(
          (list) => list.firstWhereOrNull((r) => r.uuid == recipeId),
        ),
      ),
    );

    return recipesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (recipe) {
        if (recipe == null || recipe.name.isEmpty) {
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

  /// Ephemeral serving count. null = unscaled (factor 1.0).
  /// Never written to the database.
  int? _targetServes;

  /// Derives the current scale factor from [_targetServes].
  double _scaleFactor(Recipe recipe) {
    if (_targetServes == null) return 1.0;
    final baseline = AmountUtils.extractBaselineServes(recipe.serves);
    return _targetServes! / baseline;
  }

  /// Returns the ingredient long-press callback when AI is active, or null.
  ///
  /// When null, InkWell suppresses the long-press gesture entirely.
  void Function(Ingredient)? _ingredientLongPressHandler(Recipe recipe) {
    final aiSettings = ref.watch(aiSettingsProvider);
    if (aiSettings.activeProviders.isEmpty) return null;
    return (ingredient) {
      showIngredientReferenceSheet(
        context: context,
        ref: ref,
        ingredient: ingredient,
        cuisine: recipe.cuisine,
      );
    };
  }

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
    // Use headerImage for the app bar only — no fallback to step/gallery images
    final headerImage = recipe.headerImage;
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
  /// Uses a Rich Fixed Header (two-row + background) that does not scroll
  Widget _buildSideBySideLayout(
    BuildContext context,
    Recipe recipe,
    ThemeData theme,
    bool hasHeaderImage,
    String? headerImage,
    bool hasStepImages,
  ) {
    final hasPairs = recipe.supportsPairing && _hasPairedRecipes(ref, recipe);

    return Scaffold(
      // No appBar - we build the header as part of the body
      body: Column(
        children: [
          // 1. THE RICH HEADER - Fixed at top, does not scroll
          MemoixHeader(
            title: recipe.name,
            isFavorite: recipe.isFavorite,
            headerImage: hasHeaderImage ? headerImage : null,
            onFavoritePressed: () async {
              final blocked = await ref
                  .read(recipeRepositoryProvider)
                  .toggleFavourite(recipe.id);
              if (blocked.isNotEmpty) {
                MemoixSnackBar.showError(
                    blocked.first.data['text'] as String? ?? '',);
                return;
              }
              ref.invalidate(allRecipesProvider);
              processIntegrityResponses(ref);
            },
            onLogCookPressed: () => _logCook(context, recipe),
            onSharePressed: () => _shareRecipe(context, ref),
            onComparePressed: shouldShowCompareButton(recipe)
              ? () => AppRoutes.toRecipeComparison(context, prefilledRecipe: recipe, resetState: true)
              : null,
            onEditPressed: () => AppRoutes.toRecipeEdit(context, recipeId: recipe.uuid),
            onDuplicatePressed: () => _duplicateRecipe(context, ref),
            onDeletePressed: () => _confirmDelete(context, ref),
          ),

          // 2. THE CONTENT (Split View) - Scrollable, sits below header
          Expanded(
            child: SplitRecipeView(
              recipe: recipe,
              metadataWidget: _buildCompactMetadata(recipe, theme),
              pairedRecipeChips: hasPairs
                  ? _buildPairedRecipeChips(context, ref, recipe, theme)
                  : null,
              onScrollToImage: hasStepImages ? (stepIndex) => _scrollToAndShowImage(recipe, stepIndex) : null,
              scaleFactor: _scaleFactor(recipe),
              onIngredientLongPress: _ingredientLongPressHandler(recipe),
            ),
          ),
        ],
      ),
    );
  }

  /// Build chip-style metadata (for normal scrolling views).
  Widget _buildChipMetadata(BuildContext context, Recipe recipe, ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final chipFontSize = isCompact ? 11.0 : 12.0;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Cuisine chip
        if (recipe.cuisine != null)
          Chip(
            label: Text(Cuisine.toAdjective(recipe.cuisine)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        // Pickle method chip
        if (recipe.course == 'pickles' &&
            recipe.pickleMethod != null &&
            recipe.pickleMethod!.isNotEmpty)
          Chip(
            label: Text(recipe.pickleMethod!),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        // Serves chip — long-press to scale, tap to reset.
        // Wrapped in Material(transparency)+InkWell so the ripple fires on
        // long-press initiation rather than release (GestureDetector has no
        // visual feedback).
        if (recipe.serves != null && recipe.serves!.isNotEmpty)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onLongPress: () async {
                await HapticFeedback.mediumImpact();
                if (!mounted) return;
                _showServingsBottomSheet(context, recipe);
              },
              onTap: _targetServes != null
                  ? () => setState(() => _targetServes = null)
                  : null,
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      size: 12,
                      color: _targetServes != null
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _targetServes != null
                          ? _targetServes.toString()
                          : UnitNormalizer.normalizeServes(recipe.serves!),
                    ),
                  ],
                ),
                backgroundColor: _targetServes != null
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: _targetServes != null
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontSize: chipFontSize,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        // Time chip
        if (recipe.time != null && recipe.time!.isNotEmpty)
          Chip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 12, color: theme.colorScheme.onSurface),
                const SizedBox(width: 3),
                Text(UnitNormalizer.normalizeTime(recipe.time!)),
              ],
            ),
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

  void _showServingsBottomSheet(BuildContext context, Recipe recipe) {
    final baseline = AmountUtils.extractBaselineServes(recipe.serves);
    final controller = TextEditingController(
      text: _targetServes?.toString() ?? baseline.round().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Original: ${UnitNormalizer.normalizeServes(recipe.serves!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Number of servings',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        if (_targetServes != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() => _targetServes = null);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final parsed = int.tryParse(controller.text.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() => _targetServes = parsed);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build compact text-based metadata row (for side-by-side views).
  ///
  /// The serves portion is interactive: long-press opens the servings sheet,
  /// tap resets to baseline when scaling is active. The icon and text shift to
  /// [theme.colorScheme.primary] when a custom target is set.
  Widget _buildCompactMetadata(Recipe recipe, ThemeData theme) {
    final textColor = theme.colorScheme.onSurfaceVariant;
    final baseStyle = theme.textTheme.bodySmall?.copyWith(color: textColor);
    final isDrink = recipe.course.toLowerCase() == 'drinks';

    // ── Pre-serves items: cuisine / spirit ─────────────────────────────────
    final preItems = <InlineSpan>[];

    if (isDrink) {
      // For drinks: show spirit dot + "Spirit (Cuisine)" like list view
      if (recipe.subcategory != null && recipe.subcategory!.isNotEmpty) {
        final spiritColor = MemoixColors.forSpiritDot(recipe.subcategory);
        preItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: spiritColor, shape: BoxShape.circle),
          ),
        ),);
        final spirit = Spirit.toDisplayName(recipe.subcategory!);
        if (recipe.cuisine != null && recipe.cuisine!.isNotEmpty) {
          preItems.add(TextSpan(text: '$spirit (${Cuisine.toAdjective(recipe.cuisine)})')); 
        } else {
          preItems.add(TextSpan(text: spirit));
        }
      } else if (recipe.cuisine != null) {
        final cuisineColor = MemoixColors.forContinentDot(recipe.cuisine);
        preItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: cuisineColor, shape: BoxShape.circle),
          ),
        ),);
        preItems.add(TextSpan(text: Cuisine.toAdjective(recipe.cuisine)));
      }
    } else {
      if (recipe.cuisine != null) {
        final cuisineColor = MemoixColors.forContinentDot(recipe.cuisine);
        preItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: cuisineColor, shape: BoxShape.circle),
          ),
        ),);
        preItems.add(TextSpan(text: Cuisine.toAdjective(recipe.cuisine)));
      }
    }

    // ── Post-serves items: time and glass ──────────────────────────────────
    final postItems = <InlineSpan>[];

    if (recipe.time != null && recipe.time!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeTime(recipe.time!);
      if (normalized.isNotEmpty) {
        postItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.schedule, size: 12, color: textColor),
        ),);
        postItems.add(TextSpan(text: ' $normalized'));
      }
    }

    if (isDrink && recipe.glass != null && recipe.glass!.isNotEmpty) {
      if (postItems.isNotEmpty) postItems.add(const TextSpan(text: '   '));
      postItems.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.local_bar, size: 12, color: textColor),
      ),);
      postItems.add(TextSpan(text: ' ${_capitalizeWords(recipe.glass!)}'));
    }

    // ── Serves state ────────────────────────────────────────────────────────
    final hasServes = recipe.serves != null && recipe.serves!.isNotEmpty;
    final servesNormalized = hasServes ? UnitNormalizer.normalizeServes(recipe.serves!) : '';
    final effectiveHasServes = hasServes && servesNormalized.isNotEmpty;
    final isScaled = _targetServes != null;

    if (preItems.isEmpty && !effectiveHasServes && postItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // ── Spacing: add '   ' between sections ────────────────────────────────
    // Mirror the original logic: each section adds a spacer before itself if
    // something already precedes it.
    if (preItems.isNotEmpty && (effectiveHasServes || postItems.isNotEmpty)) {
      preItems.add(const TextSpan(text: '   '));
    }
    if (postItems.isNotEmpty && (preItems.isNotEmpty || effectiveHasServes)) {
      postItems.insert(0, const TextSpan(text: '   '));
    }

    // ── Interactive serves widget ───────────────────────────────────────────
    // Wrapped in Material(transparency)+InkWell — same pattern as direction
    // step long-press in this view. Long-press fires haptic + sheet;
    // tap resets scaling when a target is active.
    Widget? servesWidget;
    if (effectiveHasServes) {
      final indicatorColor =
          isScaled ? theme.colorScheme.primary : textColor;
      final displayText =
          isScaled ? _targetServes.toString() : servesNormalized;
      servesWidget = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onLongPress: () async {
            await HapticFeedback.mediumImpact();
            if (!mounted) return;
            _showServingsBottomSheet(context, recipe);
          },
          onTap: isScaled ? () => setState(() => _targetServes = null) : null,
          child: Text.rich(
            TextSpan(
              style: baseStyle?.copyWith(color: indicatorColor),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.people, size: 12, color: indicatorColor),
                ),
                TextSpan(text: ' $displayText'),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (preItems.isNotEmpty)
          Text.rich(
            TextSpan(style: baseStyle, children: preItems),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (servesWidget != null) servesWidget,
        if (postItems.isNotEmpty)
          Text.rich(
            TextSpan(style: baseStyle, children: postItems),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  /// Build the standard layout (existing behaviour)
  Widget _buildStandardLayout(
    BuildContext context,
    Recipe recipe,
    ThemeData theme,
    bool hasHeaderImage,
    String? headerImage,
    bool hasStepImages,
  ) {
    final hasPairs = recipe.supportsPairing && _hasPairedRecipes(ref, recipe);

    return Scaffold(
      body: Column(
        children: [
          // 1. THE RICH HEADER - Fixed at top, does not scroll
          MemoixHeader(
            title: recipe.name,
            isFavorite: recipe.isFavorite,
            headerImage: hasHeaderImage ? headerImage : null,
            onFavoritePressed: () async {
              final blocked = await ref
                  .read(recipeRepositoryProvider)
                  .toggleFavourite(recipe.id);
              if (blocked.isNotEmpty) {
                MemoixSnackBar.showError(
                    blocked.first.data['text'] as String? ?? '',);
                return;
              }
              ref.invalidate(allRecipesProvider);
              processIntegrityResponses(ref);
            },
            onLogCookPressed: () => _logCook(context, recipe),
            onSharePressed: () => _shareRecipe(context, ref),
            onComparePressed: recipe.course.toLowerCase() != 'drinks' 
                ? () => AppRoutes.toRecipeComparison(context, prefilledRecipe: recipe) 
                : null,
            onEditPressed: () => AppRoutes.toRecipeEdit(context, recipeId: recipe.uuid),
            onDuplicatePressed: () => _duplicateRecipe(context, ref),
            onDeletePressed: () => _confirmDelete(context, ref),
          ),

          // 2. THE CONTENT - Scrollable
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Metadata chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildChipMetadata(context, recipe, theme),
                ),

                // Paired recipe chips
                if (hasPairs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _buildPairedRecipeChips(context, ref, recipe, theme),
                    ),
                  ),
                // Glass and Garnish (for Drinks) - side by side
                if (recipe.course == 'drinks' && 
                    ((recipe.glass != null && recipe.glass!.isNotEmpty) || recipe.garnish.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
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
                                label: Text(_capitalizeWords(recipe.glass!)),
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
                                    label: Text(_capitalizeWords(item)),
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),).toList(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // Ingredients and Directions
                LayoutBuilder(
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
                                      IngredientList(ingredients: recipe.ingredients, scaleFactor: _scaleFactor(recipe), onIngredientLongPress: _ingredientLongPressHandler(recipe)),
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
                                        enableTimerLongPress: true,
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
                          IngredientList(ingredients: recipe.ingredients, scaleFactor: _scaleFactor(recipe), onIngredientLongPress: _ingredientLongPressHandler(recipe)),
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
                            enableTimerLongPress: true,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Comments section
                if (recipe.comments != null && recipe.comments!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comments',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              recipe.comments!,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Gallery section (collapsible)
                if (hasStepImages)
                  Padding(
                    key: _stepImagesKey,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      child: ExpansionTile(
                        title: Text(
                          'Gallery',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        initiallyExpanded: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SizedBox(
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
                                                color: Colors.black.withValues(alpha: 0.5),
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
                          ),
                        ],
                      ),
                    ),
                  ),

                // Nutrition section (collapsible)
                if (recipe.nutrition != null && recipe.nutrition!.hasData)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      child: ExpansionTile(
                        title: Text(
                          'Nutrition',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        initiallyExpanded: false,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _buildNutritionContent(recipe.nutrition!, theme),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Source URL
                if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty)
                  Padding(
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

                // Bottom padding
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionContent(NutritionInfo nutrition, ThemeData theme) {
    final items = <MapEntry<String, String>>[];
    if (nutrition.calories != null) items.add(MapEntry('Calories', '${nutrition.calories}'));
    if (nutrition.proteinContent != null) items.add(MapEntry('Protein', '${nutrition.proteinContent}g'));
    if (nutrition.carbohydrateContent != null) items.add(MapEntry('Carbs', '${nutrition.carbohydrateContent}g'));
    if (nutrition.fatContent != null) items.add(MapEntry('Fat', '${nutrition.fatContent}g'));
    if (nutrition.fiberContent != null) items.add(MapEntry('Fiber', '${nutrition.fiberContent}g'));
    if (nutrition.sodiumContent != null) items.add(MapEntry('Sodium', '${nutrition.sodiumContent}mg'));
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${item.key}: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            item.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),).toList(),
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
              child: Container(color: Colors.black.withValues(alpha: 0.9)),
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
    // Select only the (uuid, pairedRecipeIds) pairs needed for pairing logic.
    final pairs = ref.watch(
      allRecipesProvider.select(
        (v) => (v.valueOrNull ?? []).map((r) => (uuid: r.uuid, pairedIds: r.pairedRecipeIds)).toList(),
      ),
    );

    if (pairs.isEmpty) return false;

    if (recipe.pairedRecipeIds.isNotEmpty) return true;

    for (final p in pairs) {
      if (p.pairedIds.contains(recipe.uuid)) return true;
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
    
    // Select only (uuid, name, course, pairedRecipeIds) — rebuilds only when
    // pairing data changes, not when unrelated fields like cookCount change.
    final pairs = ref.watch(
      allRecipesProvider.select(
        (v) => (v.valueOrNull ?? [])
            .map((r) => (uuid: r.uuid, name: r.name, course: r.course, pairedIds: r.pairedRecipeIds))
            .toList(),
      ),
    );

    if (pairs.isEmpty) return chips;

    // Collect all paired recipes (explicit + inverse)
    final pairedRecipes = <({String uuid, String name, String course})>[];

    // 1. Explicit pairings: recipes we link to
    for (final uuid in recipe.pairedRecipeIds) {
      final linked = pairs.firstWhereOrNull((p) => p.uuid == uuid);
      if (linked != null && !pairedRecipes.any((r) => r.uuid == linked.uuid)) {
        pairedRecipes.add((uuid: linked.uuid, name: linked.name, course: linked.course));
      }
    }

    // 2. Inverse pairings: recipes that link to us
    for (final p in pairs) {
      if (p.pairedIds.contains(recipe.uuid) &&
          !pairedRecipes.any((pr) => pr.uuid == p.uuid)) {
        pairedRecipes.add((uuid: p.uuid, name: p.name, course: p.course));
      }
    }
    
    // Build chips for each paired recipe
    final isCompact = MediaQuery.of(context).size.width < 600;
    for (final paired in pairedRecipes) {
      chips.add(
        ActionChip(
          avatar: CourseIconWidget(
            slug: paired.course,
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

  void _reportShare(Recipe recipe, String exportType) {
    IntegrityService.reportEvent(
      'activity.recipe_shared',
      metadata: {
        'recipe_id': recipe.uuid,
        'export_type': exportType,
        'recipe_source': recipe.source.name,
      },
    ).then((_) => processIntegrityResponses(ref));
  }

  Future<void> _logCook(BuildContext context, Recipe recipe) async {
    await ref.read(cookingStatsServiceProvider).logCook(
      recipeId: recipe.uuid,
      recipeName: recipe.name,
      course: recipe.course,
      cuisine: recipe.cuisine,
    );
    if (!mounted) return;
    ref.invalidate(cookingStatsProvider);
    ref.invalidate(recipeCookCountProvider(recipe.uuid));
    ref.invalidate(recipeLastCookProvider(recipe.uuid));
    MemoixSnackBar.showLoggedCook(
      recipeName: recipe.name,
      onViewStats: () => AppRoutes.toStatistics(context),
    );
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
                _reportShare(recipe, 'qr');
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareRecipe(recipe);
                _reportShare(recipe, 'link');
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyShareLink(recipe);
                MemoixSnackBar.show('Link copied to clipboard');
                _reportShare(recipe, 'clipboard');
              },
            ),
            ListTile(
              leading: Icon(Icons.text_snippet, color: theme.colorScheme.primary),
              title: const Text('Share as Text'),
              subtitle: const Text('Full recipe in plain text'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareAsText(recipe);
                _reportShare(recipe, 'text');
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
      ..comments = recipe.comments
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
    MemoixSnackBar.show('Created copy: ${newRecipe.name}');
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
              unawaited(SupabaseSyncService.notifyDeleted('recipes', recipe.uuid));
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
}
