import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../../../app/theme/colors.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

              // Favorite indicator
              if (recipe.isFavorite)
                const Icon(Icons.favorite, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
