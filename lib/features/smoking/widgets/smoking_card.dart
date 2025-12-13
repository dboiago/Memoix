import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';

/// Card widget for displaying a smoking recipe in a list
/// Matches RecipeCard styling with hover effects, favorite and cooked icons
class SmokingCard extends ConsumerStatefulWidget {
  final SmokingRecipe recipe;
  final VoidCallback onTap;

  const SmokingCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  ConsumerState<SmokingCard> createState() => _SmokingCardState();
}

class _SmokingCardState extends ConsumerState<SmokingCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Wood type with bullet + temp + time
                    Row(
                      children: [
                        // Wood type with colored bullet
                        Text(
                          '\u2022',
                          style: TextStyle(
                            color: MemoixColors.smoking,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.recipe.wood,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Temperature
                        Icon(
                          Icons.thermostat_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.recipe.temperature,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Time
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.recipe.time,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                      widget.recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                    ),
                    color: widget.recipe.isFavorite
                        ? Colors.red.shade400
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      ref
                          .read(smokingRepositoryProvider)
                          .toggleFavorite(widget.recipe);
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
                      ref
                          .read(smokingRepositoryProvider)
                          .incrementCookCount(widget.recipe);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${widget.recipe.name} marked as cooked'),
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
}
