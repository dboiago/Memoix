import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';
import '../../../app/theme/colors.dart';

/// Pizza card widget for list display
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
              ? MemoixColors.pizzas
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
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Cheeses and toppings summary
                    _buildIngredientsSummary(theme),
                  ],
                ),
              ),
              // Right side - base badge and favorite
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Base badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MemoixColors.pizzas.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.pizza.base.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: MemoixColors.pizzas,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      widget.pizza.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.pizza.isFavorite
                          ? Colors.red
                          : theme.colorScheme.outline,
                      size: 20,
                    ),
                    onPressed: () async {
                      final repo = ref.read(pizzaRepositoryProvider);
                      await repo.toggleFavorite(widget.pizza);
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
    
    // Add cheeses (up to 2)
    if (widget.pizza.cheeses.isNotEmpty) {
      final cheesesDisplay = widget.pizza.cheeses.take(2).join(', ');
      if (widget.pizza.cheeses.length > 2) {
        parts.add('$cheesesDisplay +${widget.pizza.cheeses.length - 2}');
      } else {
        parts.add(cheesesDisplay);
      }
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
