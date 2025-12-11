import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../models/continent_mapping.dart';
import '../../../app/theme/colors.dart';
import '../repository/recipe_repository.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../../core/providers.dart';

/// Enhanced recipe card matching Figma design
/// Shows country/region tags, servings/time icons, favorite + cooked status
class RecipeCardEnhanced extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCardEnhanced({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final country = recipe.country ?? 
        ContinentMapping.getCountryFromCuisine(recipe.cuisine);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe image or colored placeholder
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: recipe.cuisine != null
                      ? MemoixColors.forCuisine(recipe.cuisine!)
                      : MemoixColors.forCourse(recipe.course),
                  borderRadius: BorderRadius.circular(8),
                  image: recipe.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(recipe.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: recipe.imageUrl == null
                    ? Icon(
                        Icons.restaurant,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Recipe info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Country/Region tag
                    if (country != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          country,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Metadata row (servings + time)
                    Row(
                      children: [
                        if (recipe.serves != null) ...[
                          Icon(
                            Icons.people_outline,
                            size: 16,
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
                        if (recipe.time != null) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
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
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Favorite button
                  InkWell(
                    onTap: () {
                      ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: recipe.isFavorite 
                            ? Colors.red 
                            : theme.colorScheme.outline,
                        size: 22,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Cooked button
                  InkWell(
                    onTap: () {
                      ref.read(cookingStatsServiceProvider).logCook(
                        recipeId: recipe.uuid,
                        recipeName: recipe.name,
                        course: recipe.course,
                        cuisine: recipe.cuisine,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logged cook for ${recipe.name}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        recipe.cookCount > 0 
                            ? Icons.check_circle 
                            : Icons.check_circle_outline,
                        color: recipe.cookCount > 0 
                            ? Colors.green 
                            : theme.colorScheme.outline,
                        size: 22,
                      ),
                    ),
                  ),
                  
                  // Cook count badge
                  if (recipe.cookCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${recipe.cookCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
