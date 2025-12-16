import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sandwich.dart';
import '../repository/sandwich_repository.dart';

/// Sandwich card widget for list display
/// Matches PizzaCard styling with hover effects, favorite and cooked icons
class SandwichCard extends ConsumerStatefulWidget {
  final Sandwich sandwich;
  final VoidCallback? onTap;
  final bool isCompact;

  const SandwichCard({
    super.key,
    required this.sandwich,
    this.onTap,
    this.isCompact = false,
  });

  @override
  ConsumerState<SandwichCard> createState() => _SandwichCardState();
}

class _SandwichCardState extends ConsumerState<SandwichCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            horizontal: 12,
            vertical: widget.isCompact ? 6 : 10,
          ),
          child: Row(
            children: [
              // Sandwich info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sandwich name
                    Text(
                      widget.sandwich.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Only show metadata row in non-compact mode
                    if (!widget.isCompact) ...[
                      const SizedBox(height: 4),
                      // Bread with bullet + component summary
                      Row(
                        children: [
                          // Bread with bullet
                          if (widget.sandwich.bread.isNotEmpty) ...[
                            Text(
                              '\u2022',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.sandwich.bread,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Component summary
                          Flexible(
                            child: _buildComponentsSummary(theme),
                          ),
                        ],
                      ),
                    ],
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
                      widget.sandwich.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: widget.sandwich.isFavorite
                        ? Colors.red.shade400
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      await ref.read(sandwichRepositoryProvider).toggleFavorite(widget.sandwich);
                    },
                    padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
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
                    onPressed: () async {
                      await ref.read(sandwichRepositoryProvider).incrementCookCount(widget.sandwich);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${widget.sandwich.name} marked as made'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
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

  Widget _buildComponentsSummary(ThemeData theme) {
    final proteinCount = widget.sandwich.proteins.length;
    final cheeseCount = widget.sandwich.cheeses.length;

    return Row(
      children: [
        // Protein count
        if (proteinCount > 0) ...[
          Icon(
            Icons.restaurant_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '$proteinCount Protein${proteinCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
        ],
        // Cheese count
        if (cheeseCount > 0) ...[
          Icon(
            Icons.local_pizza_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '$cheeseCount Cheese${cheeseCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
