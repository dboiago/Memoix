import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';

/// Card widget for displaying a modernist recipe in a list - follows Mains pattern
class ModernistCard extends ConsumerStatefulWidget {
  final ModernistRecipe recipe;
  final VoidCallback? onTap;
  final bool isCompact;

  const ModernistCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.isCompact = false,
  });

  @override
  ConsumerState<ModernistCard> createState() => _ModernistCardState();
}

class _ModernistCardState extends ConsumerState<ModernistCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = widget.recipe;

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
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 8 : 12,
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
                      recipe.name,
                      style: widget.isCompact
                          ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)
                          : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    // Metadata row (hidden in compact mode)
                    if (!widget.isCompact) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Colored dot for Concept/Technique with distinct colors
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: MemoixColors.forModernistType(recipe.type.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Type (Concept/Technique)
                          Text(
                            recipe.type.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          // Technique category with icon if set
                          if (recipe.technique != null && recipe.technique!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.science_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recipe.technique!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          // Time if set
                          if (recipe.time != null && recipe.time!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              UnitNormalizer.normalizeTime(recipe.time!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
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
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      ref.read(modernistRepositoryProvider).toggleFavorite(recipe.id);
                    },
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),

                  const SizedBox(width: 4),

                  // Made it button
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      ref.read(modernistRepositoryProvider).incrementCookCount(recipe.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${recipe.name} marked as made'),
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
