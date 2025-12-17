import 'package:flutter/material.dart';

import '../models/smoking_recipe.dart';

/// A specialized split-view widget for "Side-by-Side Mode" that displays
/// Ingredients and Directions side-by-side with independent scrolling.
/// 
/// Adapted for Smoking recipes.
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
    final theme = Theme.of(context);
    
    // Visual density adjustments
    final isCompact = screenWidth < 600;
    final dividerPadding = isCompact ? 4.0 : 8.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ingredients Column
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

        // Vertical Divider - starts below header area
        Padding(
          padding: EdgeInsets.symmetric(horizontal: dividerPadding),
          child: Column(
            children: [
              // Spacer to match header height
              SizedBox(height: isCompact ? 36.0 : 44.0),
              // The actual divider line
              Expanded(
                child: Container(
                  width: 1,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),

        // Directions Column
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
    final headerStyle = widget.isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return CustomScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Sticky Header
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            minHeight: widget.isCompact ? 36.0 : 44.0,
            maxHeight: widget.isCompact ? 36.0 : 44.0,
            child: Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text('Ingredients', style: headerStyle),
            ),
          ),
        ),

        // Ingredients List
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _buildIngredientsList(context),
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
    final headerStyle = widget.isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return CustomScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Sticky Header
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            minHeight: widget.isCompact ? 36.0 : 44.0,
            maxHeight: widget.isCompact ? 36.0 : 44.0,
            child: Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text('Directions', style: headerStyle),
            ),
          ),
        ),

        // Directions List
        if (widget.directions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Text(
                'No directions listed',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            sliver: SliverList.builder(
              itemCount: widget.directions.length,
              itemBuilder: (context, index) {
                return _buildDirectionRow(context, index);
              },
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
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
