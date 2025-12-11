import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../../core/providers.dart';

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
      color: isDark ? const Color(0xFF1A1A1A) : theme.colorScheme.surfaceContainerHigh,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Cuisine/country dot + servings + time
                  Row(
                    children: [
                      // Cuisine indicator
                      if (cuisine != null && cuisine.isNotEmpty) ...[
                        Text(
                          '\u2022',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
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
    // Map country names to cuisine adjectives
    const map = {
      'Korea': 'Korean',
      'Korean': 'Korean',
      'China': 'Chinese',
      'Chinese': 'Chinese',
      'Japan': 'Japanese',
      'Japanese': 'Japanese',
      'Spain': 'Spanish',
      'France': 'French',
      'Italy': 'Italian',
      'Mexico': 'Mexican',
      'Mexican': 'Mexican',
      'United States': 'American',
      'North American': 'North American',
    };
    final adj = map[raw] ?? raw;
    if (subcategory != null && subcategory.isNotEmpty) {
      return '$adj ($subcategory)';
    }
    return adj;
  }
}

