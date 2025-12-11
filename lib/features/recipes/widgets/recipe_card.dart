import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../../core/providers.dart';

/// Recipe card matching Figma design
class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cuisine = recipe.cuisine;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Recipe name and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe name
                  Text(
                    recipe.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Cuisine/country dot + servings + time
                  Row(
                    children: [
                      // Cuisine indicator
                      if (cuisine != null) ...[
                        Text(
                          '\u2022',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cuisine,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // Servings
                      if (recipe.serves != null) ...[
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.serves!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // Time
                      if (recipe.time != null) ...[
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.time!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
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
                    recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                  ),
                  color: recipe.isFavorite 
                      ? Colors.red.shade400 
                      : theme.colorScheme.outline,
                  onPressed: () {
                    ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                
                const SizedBox(width: 4),
                
                // Cooked button
                IconButton(
                  icon: Icon(
                    recipe.cookCount > 0 
                        ? Icons.check_circle 
                        : Icons.check_circle_outline,
                    size: 20,
                  ),
                  color: recipe.cookCount > 0 
                      ? Colors.green.shade400 
                      : theme.colorScheme.outline,
                  onPressed: () {
                    ref.read(cookingStatsServiceProvider).logCook(
                      recipeId: recipe.uuid,
                      recipeName: recipe.name,
                      course: recipe.course,
                      cuisine: recipe.cuisine,
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
    );
  }
}

