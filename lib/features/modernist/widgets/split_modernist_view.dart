import 'package:flutter/material.dart';

import '../models/modernist_recipe.dart';

/// A specialized split-view widget for "Side-by-Side Mode" that displays
/// Ingredients and Directions side-by-side with independent scrolling.
/// 
/// Adapted from the Recipe split view for Modernist recipes.
class SplitModernistView extends StatelessWidget {
  final ModernistRecipe recipe;
  final Function(int stepIndex)? onScrollToImage;

  const SplitModernistView({
    super.key,
    required this.recipe,
    this.onScrollToImage,
  });

  /// Calculate the flex ratio for ingredients column based on screen width.
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
              ingredients: recipe.ingredients,
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
  final List<ModernistIngredient> ingredients;
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
    final headerStyle = widget.isCompact
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    // Group ingredients by section
    final grouped = _groupBySection(widget.ingredients);

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
        if (widget.ingredients.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Text(
                'No ingredients listed',
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
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildGroupedIngredientsList(context, grouped),
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

  List<Widget> _buildGroupedIngredientsList(BuildContext context, Map<String, List<_IndexedIngredient>> grouped) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      final section = entry.key;
      final items = entry.value;

      // Section header
      if (section.isNotEmpty) {
        widgets.add(
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
        );
      }

      // Ingredients in this section
      for (final item in items) {
        widgets.add(_buildIngredientRow(context, item));
      }
    }

    return widgets;
  }

  Widget _buildIngredientRow(BuildContext context, _IndexedIngredient item) {
    final theme = Theme.of(context);
    final index = item.index;
    final ingredient = item.ingredient;
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

            // Content - vertical layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ingredient name
                  Text(
                    ingredient.name,
                    style: TextStyle(
                      fontSize: widget.isCompact ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : null,
                    ),
                  ),

                  // Amount
                  if (ingredient.displayText != ingredient.name)
                    Text(
                      ingredient.displayText.replaceFirst(ingredient.name, '').trim(),
                      style: TextStyle(
                        fontSize: widget.isCompact ? 11 : 12,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                  // Notes
                  if (ingredient.notes != null && ingredient.notes!.isNotEmpty)
                    Text(
                      ingredient.notes!,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 10 : 11,
                        fontStyle: FontStyle.italic,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : theme.colorScheme.primary,
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
  final ModernistRecipe? recipe;
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

/// Helper class for indexed ingredients
class _IndexedIngredient {
  final int index;
  final ModernistIngredient ingredient;

  _IndexedIngredient(this.index, this.ingredient);
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
