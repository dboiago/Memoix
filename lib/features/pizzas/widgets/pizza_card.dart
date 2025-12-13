import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';
import '../../../app/theme/colors.dart';

/// Pizza card widget for list display
/// Matches RecipeCard styling with hover effects, favorite and cooked icons
class PizzaCard extends ConsumerStatefulWidget {
  final Pizza pizza;
  final VoidCallback? onTap;

  const PizzaCard({
    super.key,
    required this.pizza,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    const SizedBox(height: 4),
                    // Base with bullet + cheeses/toppings summary
                    Row(
                      children: [
                        // Base with colored bullet
                        Text(
                          '\u2022',
                          style: TextStyle(
                            color: MemoixColors.pizzas,
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
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Cooked button
                  IconButton(
                    icon: Icon(
                      widget.pizza.cookCount > 0 
                          ? Icons.check_circle 
                          : Icons.check_circle_outline,
                      size: 20,
                    ),
                    color: widget.pizza.cookCount > 0 
                        ? Colors.green.shade400 
                        : theme.colorScheme.onSurfaceVariant,
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

  Widget _buildIngredientsSummary(ThemeData theme) {
    final parts = <String>[];
    
    // Add cheeses count
    if (widget.pizza.cheeses.isNotEmpty) {
      parts.add('${widget.pizza.cheeses.length} cheese${widget.pizza.cheeses.length == 1 ? '' : 's'}');
    }
    
    // Add toppings count
    if (widget.pizza.toppings.isNotEmpty) {
      parts.add('${widget.pizza.toppings.length} topping${widget.pizza.toppings.length == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
