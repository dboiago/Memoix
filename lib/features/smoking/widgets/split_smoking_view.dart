import 'dart:io';

import 'package:flutter/material.dart';

import '../models/smoking_recipe.dart';

/// A specialized split-view widget for "Side-by-Side Mode" that displays
/// Ingredients and Directions side-by-side with independent scrolling.
/// 
/// Adapted for Smoking recipes.
/// The split columns are constrained to 85% of screen height, allowing
/// the user to scroll the parent page to see Comments and other footer content.
class SplitSmokingView extends StatelessWidget {
  final SmokingRecipe recipe;
  final Function(int stepIndex)? onScrollToImage;

  const SplitSmokingView({
    super.key,
    required this.recipe,
    this.onScrollToImage,
  });

  /// Calculate the flex ratio for ingredients column based on screen width.
  int _getIngredientsFlex(double width) {
    if (width < 600) {
      return 1; // 50% on mobile
    }
    return 1; // ~35% on tablet
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
    
    // Visual density adjustments
    final isCompact = screenWidth < 600;
    final dividerPadding = isCompact ? 4.0 : 8.0;
    final headerHeight = isCompact ? 36.0 : 44.0;
    final padding = isCompact ? 8.0 : 12.0;
    final headerStyle = isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    
    // Calculate split view height (85% of screen, clamped for usability)
    final splitViewHeight = (screenHeight * 0.85).clamp(400.0, 900.0);
    
    // Check for extra content sections
    final hasNotes = recipe.notes != null && recipe.notes!.isNotEmpty;
    final hasGallery = recipe.stepImages.isNotEmpty;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      // Divider spacer
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
                              recipe: recipe,
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
                              recipe: recipe,
                              onScrollToImage: onScrollToImage,
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
          
          // Bottom padding
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context, SmokingRecipe recipe, ThemeData theme) {
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
  final SmokingRecipe recipe;
  final bool isCompact;

  const _IngredientsColumn({
    required this.recipe,
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

    return ListView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: padding).copyWith(bottom: 32),
      children: _buildIngredientsList(context),
    );
  }

  List<Widget> _buildIngredientsList(BuildContext context) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    final recipe = widget.recipe;

    if (recipe.type == SmokingType.pitNote) {
      // Pit Note: show main item and seasonings
      if (recipe.item != null && recipe.item!.isNotEmpty) {
        widgets.add(_buildSectionHeader(theme, 'Main'));
        widgets.add(_buildIngredientRow(context, 0, recipe.item!));
      }
      
      if (recipe.seasonings.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildSectionHeader(
          theme, 
          recipe.seasonings.length == 1 ? 'Seasoning' : 'Seasonings',
        ));
        for (var i = 0; i < recipe.seasonings.length; i++) {
          widgets.add(_buildIngredientRow(
            context, 
            i + 1, // Offset by 1 for the main item
            recipe.seasonings[i].displayText,
          ));
        }
      }
    } else {
      // Recipe type: show full ingredients
      if (recipe.ingredients.isEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'No ingredients listed',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else {
        for (var i = 0; i < recipe.ingredients.length; i++) {
          widgets.add(_buildIngredientRow(
            context, 
            i,
            recipe.ingredients[i].displayText,
          ));
        }
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildIngredientRow(BuildContext context, int index, String text) {
    final theme = Theme.of(context);
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            SizedBox(
              width: 20,
              height: 20,
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
            const SizedBox(width: 8),

            // Text
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: widget.isCompact ? 13 : 14,
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
  }
}

/// Directions column with sticky header and independent scrolling.
class _DirectionsColumn extends StatefulWidget {
  final List<String> directions;
  final SmokingRecipe? recipe;
  final Function(int stepIndex)? onScrollToImage;
  final bool isCompact;

  const _DirectionsColumn({
    required this.directions,
    this.recipe,
    this.onScrollToImage,
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

    if (widget.directions.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Text(
          'No directions listed',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: padding).copyWith(bottom: 32),
      itemCount: widget.directions.length,
      itemBuilder: (context, index) {
        return _buildDirectionRow(context, index);
      },
    );
  }

  Widget _buildDirectionRow(BuildContext context, int index) {
    final theme = Theme.of(context);
    final step = widget.directions[index];
    final isCompleted = _completedSteps.contains(index);
    final hasImage = widget.recipe?.getStepImageIndex(index) != null;
    
    final circleSize = widget.isCompact ? 20.0 : 24.0;
    final circleFontSize = widget.isCompact ? 10.0 : 12.0;
    final stepFontSize = widget.isCompact ? 13.0 : 14.0;

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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number circle
            Container(
              width: circleSize,
              height: circleSize,
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
                    ? Icon(Icons.check, size: circleSize * 0.6, color: theme.colorScheme.secondary)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: circleFontSize,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // Step text
            Expanded(
              child: Text(
                step,
                style: TextStyle(
                  fontSize: stepFontSize,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : null,
                ),
              ),
            ),

            // Image icon if step has an image
            if (hasImage)
              IconButton(
                icon: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'View step image',
                onPressed: () => widget.onScrollToImage?.call(index),
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
