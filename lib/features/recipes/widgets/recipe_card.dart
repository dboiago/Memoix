import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../../../app/theme/colors.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../statistics/models/cooking_stats.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                width: 60,
                height: 60,
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
                        color: Colors.white.withOpacity(0.7),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Metadata row
                    DefaultTextStyle(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: Row(
                        children: [
                          if (recipe.serves != null) ...[
                            const Icon(Icons.people, size: 14),
                            const SizedBox(width: 4),
                            Text(recipe.serves!),
                            const SizedBox(width: 12),
                          ],
                          if (recipe.time != null) ...[
                            const Icon(Icons.timer, size: 14),
                            const SizedBox(width: 4),
                            Text(recipe.time!),
                          ],
                        ],
                      ),
                    ),

                    // Pairs with (if any)
                    if (recipe.pairsWith.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pairs with: ${recipe.pairsWith.join(", ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action icons
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: recipe.isFavorite ? Colors.red : null,
                    ),
                    onPressed: () {
                      ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'I made this',
                    onPressed: () {
                      ref.read(cookingStatsServiceProvider).logCook(
                        recipeId: recipe.uuid,
                        recipeName: recipe.name,
                        course: recipe.course,
                        cuisine: recipe.cuisine,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged cook for ${recipe.name}')));
                    },
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
