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
  final bool isCompact;

  const SmokingCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.isCompact = false,
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
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: widget.isCompact ? 6 : 10,
          ),
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
                    if (!widget.isCompact) const SizedBox(height: 4),

                    // Item/category with colored bullet + wood with tree icon + temp + time
                    Row(
                      children: [
                        // Category/Item with colored bullet
                        if (widget.recipe.category != null) ...[
                          Text(
                            '\u2022',
                            style: TextStyle(
                              color: MemoixColors.forSmokedItemDot(widget.recipe.category),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.recipe.category!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Wood type with tree icon (no colored dot)
                        Icon(
                          Icons.park,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.recipe.wood,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!widget.isCompact) const SizedBox(width: 12),

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
                        if (!widget.isCompact) const SizedBox(width: 12),

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
                          .toggleFavorite(widget.recipe.uuid);
                    },
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),

                  if (!widget.isCompact) const SizedBox(width: 4),

                  // Cooked button
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      ref
                          .read(smokingRepositoryProvider)
                          .incrementCookCount(widget.recipe.uuid);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${widget.recipe.name} marked as cooked'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
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
