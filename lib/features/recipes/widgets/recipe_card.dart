import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../../core/providers.dart';
import '../../../app/theme/colors.dart';

/// Recipe card matching Figma design
class RecipeCard extends ConsumerStatefulWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  ConsumerState<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends ConsumerState<RecipeCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisine = widget.recipe.cuisine;

    final bool isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (_hovered || _pressed)
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withValues(alpha: 0.12),
          width: (_hovered || _pressed) ? 1.5 : 1.0,
        ),
      ),
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovered = h),
        onHighlightChanged: (p) => setState(() => _pressed = p),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Recipe name and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe name
                  Text(
                    widget.recipe.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Cuisine/spirit indicator dot + servings + time
                  Row(
                    children: [
                      // For drinks: show spirit dot, for food: show cuisine dot
                      if (_isDrink()) ...[
                        // Spirit indicator for drinks
                        if (widget.recipe.subcategory != null && widget.recipe.subcategory!.isNotEmpty) ...[
                          Text(
                            '\u2022',
                            style: TextStyle(
                              color: MemoixColors.forSpiritDot(widget.recipe.subcategory),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _displayDrinkInfo(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else if (cuisine != null && cuisine.isNotEmpty) ...[
                          // Fallback to cuisine for drinks without spirit (e.g., Korean tea)
                          Text(
                            '\u2022',
                            style: TextStyle(
                              color: MemoixColors.forContinentDot(cuisine),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            Cuisine.toAdjective(cuisine),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ] else if (cuisine != null && cuisine.isNotEmpty) ...[
                        // Cuisine indicator for food recipes
                        Text(
                          '\u2022',
                          style: TextStyle(
                            color: MemoixColors.forContinentDot(cuisine),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _displayCuisine(cuisine, widget.recipe.subcategory),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // Servings
                      if (widget.recipe.serves != null) ...[
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.recipe.serves!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // Time
                      if (widget.recipe.time != null) ...[
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.recipe.time!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action icons (favorite + cooked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favorite button
                IconButton(
                  icon: Icon(
                    widget.recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                  ),
                  color: widget.recipe.isFavorite 
                      ? Colors.red.shade400 
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    ref.read(recipeRepositoryProvider).toggleFavorite(widget.recipe.id);
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                
                const SizedBox(width: 4),
                
                // Cooked button
                IconButton(
                  icon: Icon(
                    widget.recipe.cookCount > 0 
                        ? Icons.check_circle 
                        : Icons.check_circle_outline,
                    size: 20,
                  ),
                  color: widget.recipe.cookCount > 0 
                      ? Colors.green.shade400 
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    ref.read(cookingStatsServiceProvider).logCook(
                      recipeId: widget.recipe.uuid,
                      recipeName: widget.recipe.name,
                      course: widget.recipe.course,
                      cuisine: widget.recipe.cuisine,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.recipe.name} marked as cooked'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  String _displayCuisine(String raw, String? subcategory) {
    // Use the comprehensive Cuisine.toAdjective() method
    final adj = Cuisine.toAdjective(raw);
    if (subcategory != null && subcategory.isNotEmpty) {
      return '$adj ($subcategory)';
    }
    return adj;
  }

  /// Check if this recipe is a drink/cocktail
  bool _isDrink() {
    final course = widget.recipe.course?.toLowerCase();
    return course == 'drinks' || course == 'drink' || course == 'beverages';
  }

  /// Display drink info: spirit name + optional cuisine origin
  String _displayDrinkInfo() {
    final spirit = widget.recipe.subcategory ?? '';
    final cuisine = widget.recipe.cuisine;
    
    // Show spirit name, with cuisine if it's an origin-specific drink
    if (cuisine != null && cuisine.isNotEmpty) {
      final cuisineAdj = Cuisine.toAdjective(cuisine);
      return '$spirit ($cuisineAdj)';
    }
    return Spirit.toDisplayName(spirit);
  }
}

