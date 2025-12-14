import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';

/// Pizza card widget for list display
/// Matches RecipeCard styling with hover effects, favorite and cooked icons
class PizzaCard extends ConsumerStatefulWidget {
  final Pizza pizza;
  final VoidCallback? onTap;
  final bool isCompact;

  const PizzaCard({
    super.key,
    required this.pizza,
    this.onTap,
    this.isCompact = false,
  });

  @override
  ConsumerState<PizzaCard> createState() => _PizzaCardState();
}

class _PizzaCardState extends ConsumerState<PizzaCard> {
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
              // Pizza info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pizza name
                    Text(
                      widget.pizza.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Only show metadata row in non-compact mode
                    if (!widget.isCompact) ...[
                      const SizedBox(height: 4),
                      // Base with bullet + cheeses/toppings summary
                      Row(
                        children: [
                          // Base with sauce-themed colored bullet
                          Text(
                            '\u2022',
                            style: TextStyle(
                              color: MemoixColors.forPizzaBaseDot(widget.pizza.base.name),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.pizza.base.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Cheeses and toppings summary
                          Flexible(
                            child: _buildIngredientsSummary(theme),
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
                      widget.pizza.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: widget.pizza.isFavorite
                        ? Colors.red.shade400
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      await ref.read(pizzaRepositoryProvider).toggleFavorite(widget.pizza);
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
                      await ref.read(pizzaRepositoryProvider).incrementCookCount(widget.pizza);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${widget.pizza.name} marked as cooked'),
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

  Widget _buildIngredientsSummary(ThemeData theme) {
    final cheeseCount = widget.pizza.cheeses.length;
    final toppingCount = widget.pizza.toppings.length;

    return Row(
      children: [
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
          const SizedBox(width: 12),
        ],
        // Topping count
        if (toppingCount > 0) ...[
          Icon(
            Icons.restaurant_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '$toppingCount Topping${toppingCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
