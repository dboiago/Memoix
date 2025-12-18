import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';

/// A specialized split-view widget for "Side-by-Side Mode" that displays
/// Ingredients and Directions side-by-side with independent scrolling.
/// 
/// This view is designed for active cooking, allowing the user to
/// reference ingredients while reading directions without losing their place.
/// 
/// Notes, Nutrition, and Gallery sections appear below the split columns
/// in a shared scrollable area, matching the layout of normal mode.
class SplitRecipeView extends StatelessWidget {
  final Recipe recipe;
  final Function(int stepIndex)? onScrollToImage;
  final Widget? metadataWidget;
  final List<Widget>? pairedRecipeChips;

  const SplitRecipeView({
    super.key,
    required this.recipe,
    this.onScrollToImage,
    this.metadataWidget,
    this.pairedRecipeChips,
  });

  /// Calculate the flex ratio for ingredients column based on screen width.
  /// - Mobile (<600px): 50/50 split - space is premium
  /// - Tablet/Landscape (≥600px): 35/65 split - directions need more room
  int _getIngredientsFlex(double width) {
    if (width < 600) {
      return 1; // 50% on mobile
    }
    return 1; // ~35% on tablet (paired with 2 for directions)
  }

  /// Calculate the flex ratio for directions column based on screen width.
  int _getDirectionsFlex(double width) {
    if (width < 600) {
      return 1; // 50% on mobile
    }
    return 2; // ~65% on tablet
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    
    // Visual density adjustments for cockpit mode
    final isCompact = screenWidth < 600;
    final dividerPadding = isCompact ? 4.0 : 8.0;
    final headerHeight = isCompact ? 36.0 : 44.0;
    final padding = isCompact ? 8.0 : 12.0;
    final headerStyle = isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    // Check if this is a drink with glass/garnish info
    final isDrink = recipe.course?.toLowerCase() == 'drinks';
    final hasGlassOrGarnish = isDrink && 
        ((recipe.glass != null && recipe.glass!.isNotEmpty) || recipe.garnish.isNotEmpty);
    
    // Calculate max split view height (85% of screen, clamped for usability)
    final maxSplitHeight = (screenHeight * 0.85).clamp(400.0, 900.0);
    
    // Estimate content height based on item counts to avoid dead space
    // Ingredients: ~50px per item (name + amount + padding)
    // Directions: ~70px per step (text wraps, step number, padding)
    final ingredientHeight = recipe.ingredients.length * 50.0 + 80; // header + padding
    final directionsHeight = recipe.directions.length * 70.0 + 80;
    final estimatedContentHeight = ingredientHeight > directionsHeight ? ingredientHeight : directionsHeight;
    
    // Use the smaller of estimated content or max height, with minimum for usability
    final splitViewHeight = estimatedContentHeight.clamp(200.0, maxSplitHeight);
    
    // Check for extra content sections
    final hasNotes = recipe.notes != null && recipe.notes!.isNotEmpty;
    final hasGallery = recipe.stepImages.isNotEmpty;
    final hasNutrition = recipe.nutrition != null;
    final hasSourceUrl = recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata row (compact text below header) - uses scaffold background
          if (metadataWidget != null)
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              width: double.infinity,
              child: metadataWidget!,
            ),
          // Paired recipe chips (if any) - uses scaffold background
          if (pairedRecipeChips != null && pairedRecipeChips!.isNotEmpty)
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
              width: double.infinity,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: pairedRecipeChips!,
              ),
            ),
          // Glass and Garnish for drinks - uses scaffold background, matches normal mode
          if (hasGlassOrGarnish)
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
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
                            fontSize: isCompact ? 12 : 14,
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
                                fontSize: isCompact ? 12 : 14,
                              ),
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          
          // Spacing after meta chip area (only if there are meta chips)
          if (metadataWidget != null || 
              (pairedRecipeChips != null && pairedRecipeChips!.isNotEmpty) || 
              hasGlassOrGarnish)
            const SizedBox(height: 12),
          
          // Split columns card with rounded corners (matches normal mode cards)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Fixed header row for split columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ingredients header
                      Expanded(
                        flex: _getIngredientsFlex(screenWidth),
                        child: Container(
                          height: headerHeight,
                          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
                          alignment: Alignment.centerLeft,
                          child: Text('Ingredients', style: headerStyle),
                        ),
                      ),
                      // Divider spacer (matches divider padding)
                      SizedBox(width: dividerPadding * 2 + 1),
                      // Directions header
                      Expanded(
                        flex: _getDirectionsFlex(screenWidth),
                        child: Container(
                          height: headerHeight,
                          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
                          alignment: Alignment.centerLeft,
                          child: Text('Directions', style: headerStyle),
                        ),
                      ),
                    ],
                  ),
                  
                  // Split columns container with fixed height (85% of screen)
                  SizedBox(
                    height: splitViewHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ingredients Column - independently scrollable
                        Expanded(
                          flex: _getIngredientsFlex(screenWidth),
                          child: ScrollbarTheme(
                            data: ScrollbarThemeData(
                              thickness: WidgetStateProperty.all(2.0),
                            ),
                            child: _IngredientsColumn(
                              ingredients: recipe.ingredients,
                              isCompact: isCompact,
                            ),
                          ),
                        ),

                        // Vertical Divider
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: dividerPadding),
                          child: Container(
                            width: 1,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                          ),
                        ),

                        // Directions Column - independently scrollable
                        Expanded(
                          flex: _getDirectionsFlex(screenWidth),
                          child: ScrollbarTheme(
                            data: ScrollbarThemeData(
                              thickness: WidgetStateProperty.all(2.0),
                            ),
                            child: _DirectionsColumn(
                              directions: recipe.directions,
                              isCompact: isCompact,
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
          
          // ===== FOOTER SECTIONS (scrollable via parent) =====
          
          // Comments/Notes section - full width card
          if (hasNotes)
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comments',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(recipe.notes!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Gallery section (collapsible) - full width card
          if (hasGallery)
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  child: Theme(
                    data: theme.copyWith(
                      splashColor: theme.colorScheme.surfaceContainerHighest,
                      hoverColor: theme.colorScheme.surfaceContainerHighest,
                    ),
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
                          child: _buildImageGallery(context, recipe, theme),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Nutrition section (collapsible) - full width card
          if (hasNutrition)
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  child: Theme(
                    data: theme.copyWith(
                      splashColor: theme.colorScheme.surfaceContainerHighest,
                      hoverColor: theme.colorScheme.surfaceContainerHighest,
                    ),
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
                          child: _buildNutritionGrid(recipe.nutrition!, theme),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Source URL (View Original Recipe)
          if (hasSourceUrl)
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Original Recipe'),
                  onPressed: () async {
                    final url = Uri.tryParse(recipe.sourceUrl!);
                    if (url != null) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),
          
          // Bottom padding
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildNutritionGrid(NutritionInfo nutrition, ThemeData theme) {
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
      )).toList(),
    );
  }

  Widget _buildImageGallery(BuildContext context, Recipe recipe, ThemeData theme) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recipe.stepImages.length,
        itemBuilder: (context, imageIndex) {
          final imagePath = recipe.stepImages[imageIndex];
          return Padding(
            padding: EdgeInsets.only(left: imageIndex == 0 ? 0 : 8),
            child: GestureDetector(
              onTap: () => _showImageFullscreen(context, imagePath),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: _buildStepImage(imagePath, theme),
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
    );
  }

  Widget _buildStepImage(String imagePath, ThemeData theme) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
        ),
      );
    }
  }

  void _showImageFullscreen(BuildContext context, String imagePath) {
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
}

/// Ingredients column with sticky header and independent scrolling.
class _IngredientsColumn extends StatefulWidget {
  final List<Ingredient> ingredients;
  final bool isCompact;

  const _IngredientsColumn({
    required this.ingredients,
    required this.isCompact,
  });

  @override
  State<_IngredientsColumn> createState() => _IngredientsColumnState();
}

class _IngredientsColumnState extends State<_IngredientsColumn> {
  final Set<int> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = widget.isCompact ? 8.0 : 12.0;

    return ListView.builder(
      primary: false,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.symmetric(horizontal: padding).copyWith(bottom: 16),
      itemCount: widget.ingredients.isEmpty ? 1 : widget.ingredients.length,
      itemBuilder: (context, index) {
        if (widget.ingredients.isEmpty) {
          return Text(
            'No ingredients listed',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        final ingredient = widget.ingredients[index];
        final isChecked = _checkedItems.contains(index);
        return _buildIngredientRow(context, ingredient, index, isChecked);
      },
    );
  }

  Widget _buildIngredientRow(
    BuildContext context,
    Ingredient ingredient,
    int index,
    bool isChecked,
  ) {
    final theme = Theme.of(context);
    final checkboxSize = widget.isCompact ? 18.0 : 22.0;
    final verticalPadding = widget.isCompact ? 4.0 : 6.0;
    final fontSize = widget.isCompact ? 12.0 : 14.0;
    final textStyle = TextStyle(fontSize: fontSize);

    // Build amount string
    String amountText = '';
    if (ingredient.amount != null && ingredient.amount!.isNotEmpty) {
      amountText = _formatAmount(ingredient.amount!);
      if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
        amountText += ' ${ingredient.unit}';
      }
    }

    // Parse notes to extract optional markers and alternatives
    final rawNotes = [
      if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) ingredient.preparation!,
      if (ingredient.alternative != null && ingredient.alternative!.isNotEmpty) ingredient.alternative!,
    ].where((s) => s.isNotEmpty).join(' · ');
    
    final parsedNotes = _parseNotes(rawNotes);
    
    // Determine if ingredient is optional (from field OR parsed from notes)
    final isOptional = ingredient.isOptional || parsedNotes.isOptional;
    
    // Get parsed alternative
    final extractedAlt = parsedNotes.alternative;
    
    // Final notes text after removing optional/alt patterns
    final notesText = parsedNotes.remainingNotes;
    final hasNotes = notesText.isNotEmpty;

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
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact checkbox
            SizedBox(
              width: checkboxSize,
              height: checkboxSize,
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
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(width: widget.isCompact ? 4 : 6),

            // Ingredient content - vertical layout: name, amount, notes, alternative
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ingredient name with optional badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _capitalizeWords(ingredient.name),
                          style: textStyle.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Optional badge (compact)
                      if (isOptional) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'opt',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 9 : 10,
                              color: theme.colorScheme.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Amount on its own line
                  if (amountText.isNotEmpty)
                    Text(
                      amountText,
                      style: textStyle.copyWith(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  // Preparation/notes on its own line (if present)
                  if (hasNotes)
                    Text(
                      notesText,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 10 : 11,
                        fontStyle: FontStyle.italic,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  // Alternative on its own line (if present)
                  if (extractedAlt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'alt: $extractedAlt',
                              style: TextStyle(
                                fontSize: widget.isCompact ? 9 : 10,
                                color: isChecked
                                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                                    : theme.colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
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
}

/// Directions column with sticky header and independent scrolling.
class _DirectionsColumn extends StatefulWidget {
  final List<String> directions;
  final bool isCompact;

  const _DirectionsColumn({
    required this.directions,
    required this.isCompact,
  });

  @override
  State<_DirectionsColumn> createState() => _DirectionsColumnState();
}

class _DirectionsColumnState extends State<_DirectionsColumn> {
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = widget.isCompact ? 8.0 : 12.0;

    // Build list of direction items only
    final items = <Widget>[];
    
    // Add directions
    if (widget.directions.isEmpty) {
      items.add(Text(
        'No directions listed',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    } else {
      for (int i = 0; i < widget.directions.length; i++) {
        items.add(_buildDirectionRow(context, i));
      }
    }

    return ListView(
      primary: false,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.symmetric(horizontal: padding).copyWith(bottom: 16),
      children: items,
    );
  }

  /// Check if a step is a section header (wrapped in square brackets)
  bool _isSection(String step) {
    final trimmed = step.trim();
    return trimmed.startsWith('[') && trimmed.endsWith(']');
  }

  /// Extract section name from brackets
  String _getSectionName(String step) {
    final trimmed = step.trim();
    return trimmed.substring(1, trimmed.length - 1);
  }

  Widget _buildDirectionRow(BuildContext context, int index) {
    final theme = Theme.of(context);
    final step = widget.directions[index];
    
    // Section header
    if (_isSection(step)) {
      return Padding(
        padding: EdgeInsets.only(
          top: index > 0 ? (widget.isCompact ? 12 : 16) : 0,
          bottom: widget.isCompact ? 4 : 8,
        ),
        child: Text(
          _getSectionName(step),
          style: (widget.isCompact ? theme.textTheme.labelLarge : theme.textTheme.titleSmall)?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    // Calculate step number (excluding section headers)
    int stepNumber = 0;
    for (int i = 0; i <= index; i++) {
      if (!_isSection(widget.directions[i])) {
        stepNumber++;
      }
    }

    final isCompleted = _completedSteps.contains(index);
    
    final circleSize = widget.isCompact ? 20.0 : 24.0;
    final circleIconSize = widget.isCompact ? 10.0 : 14.0;
    final circleFontSize = widget.isCompact ? 10.0 : 12.0;
    final verticalPadding = widget.isCompact ? 4.0 : 6.0;
    final fontSize = widget.isCompact ? 12.0 : 14.0;

    return InkWell(
      onTap: () {
        setState(() {
          if (isCompleted) {
            _completedSteps.remove(index);
          } else {
            _completedSteps.add(index);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number circle
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.secondary.withOpacity(0.15),
                border: Border.all(
                  color: isCompleted
                      ? theme.colorScheme.outline.withOpacity(0.5)
                      : theme.colorScheme.secondary,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, size: circleIconSize, color: theme.colorScheme.outline)
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: circleFontSize,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
              ),
            ),
            SizedBox(width: widget.isCompact ? 6 : 8),

            // Step text
            Expanded(
              child: Text(
                _capitalizeSentence(step),
                style: TextStyle(
                  fontSize: fontSize,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delegate for sticky headers in CustomScrollView
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// ============================================================================
// Helper functions (duplicated from ingredient_list.dart for isolation)
// ============================================================================

/// Result of parsing ingredient notes for special patterns
class _ParsedNotes {
  final bool isOptional;
  final String? alternative;
  final String remainingNotes;

  _ParsedNotes({
    required this.isOptional,
    this.alternative,
    required this.remainingNotes,
  });
}

/// Parse notes text to extract optional markers and alternatives
_ParsedNotes _parseNotes(String notes) {
  if (notes.isEmpty) {
    return _ParsedNotes(isOptional: false, remainingNotes: '');
  }

  var remaining = notes;
  var isOptional = false;
  String? alternative;

  // Patterns for optional markers
  final optionalPatterns = [
    RegExp(r'\(optional\)', caseSensitive: false),
    RegExp(r'\(opt\.?\)', caseSensitive: false),
    RegExp(r'^optional$', caseSensitive: false),
    RegExp(r'^opt\.?$', caseSensitive: false),
    RegExp(r',?\s*optional\s*,?', caseSensitive: false),
    RegExp(r',?\s*opt\.?\s*,?', caseSensitive: false),
  ];

  for (final pattern in optionalPatterns) {
    if (pattern.hasMatch(remaining)) {
      isOptional = true;
      remaining = remaining.replaceAll(pattern, ' ').trim();
    }
  }

  // Patterns for alternative ingredients
  final altPatterns = [
    RegExp(r',?\s*alt(?:ernative)?:\s*([^,;]+)', caseSensitive: false),
    RegExp(r',?\s*sub(?:stitute)?:\s*([^,;]+)', caseSensitive: false),
    RegExp(r',?\s*or\s+(?:use\s+)?([^,;]+)', caseSensitive: false),
    RegExp(r'\(or\s+([^)]+)\)', caseSensitive: false),
  ];

  for (final pattern in altPatterns) {
    final match = pattern.firstMatch(remaining);
    if (match != null) {
      alternative = match.group(1)?.trim();
      remaining = remaining.replaceFirst(pattern, ' ').trim();
      break;
    }
  }

  // Clean up remaining text
  remaining = remaining
      .replaceAll(RegExp(r'^[\s·,;:\-–—]+'), '')
      .replaceAll(RegExp(r'[\s·,;:\-–—]+$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return _ParsedNotes(
    isOptional: isOptional,
    alternative: alternative,
    remainingNotes: remaining,
  );
}

/// Format amount to clean up decimals and display fractions
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
  
  // Convert common decimal fractions to unicode fractions
  final fractionMap = {
    '.5': '½',
    '.25': '¼',
    '.75': '¾',
    '.33': '⅓',
    '.333': '⅓',
    '.67': '⅔',
    '.667': '⅔',
  };
  
  for (final entry in fractionMap.entries) {
    result = result.replaceAllMapped(
      RegExp('(\\d+)${RegExp.escape(entry.key)}(?=\\s|\$|-|–)'),
      (match) => '${match.group(1)}${entry.value}',
    );
    if (result == entry.key || result.startsWith('${entry.key} ')) {
      result = result.replaceFirst(entry.key, entry.value);
    }
  }
  
  // Text fractions
  final textFractionMap = {
    '1/2': '½',
    '1/4': '¼',
    '3/4': '¾',
    '1/3': '⅓',
    '2/3': '⅔',
  };
  
  for (final entry in textFractionMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  
  return result;
}

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

/// Capitalize the first letter of a sentence
String _capitalizeSentence(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
