import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/widgets/memoix_snackbar.dart';
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
                      // Protein summary with themed dot
                      _buildProteinSummary(theme),
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
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      await ref.read(sandwichRepositoryProvider).toggleFavorite(widget.sandwich);
                      await processIntegrityResponses(ref);
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
                      MemoixSnackBar.showLoggedCook(
                        recipeName: widget.sandwich.name,
                        onViewStats: () => AppRoutes.toStatistics(context),
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

  /// Build protein summary: first protein, "Cheese" (vegetarian), or "Assorted"
  Widget _buildProteinSummary(ThemeData theme) {
    final proteins = widget.sandwich.proteins;
    final cheeses = widget.sandwich.cheeses;
    
    String label;
    Color dotColor;
    
    if (proteins.isEmpty) {
      // Vegetarian - show "Cheese"
      if (cheeses.isNotEmpty) {
        label = 'Cheese';
        dotColor = MemoixColors.cheese;
      } else {
        // No proteins and no cheese - shouldn't happen often
        return const SizedBox.shrink();
      }
    } else if (proteins.length == 1) {
      // Single protein - show it with protein-specific color
      label = proteins.first;
      dotColor = MemoixColors.forProteinDot(proteins.first);
    } else {
      // Multiple proteins - show "Assorted" with first protein's color
      label = 'Assorted';
      dotColor = MemoixColors.forProteinDot(proteins.first);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\u2022',
          style: TextStyle(
            color: dotColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Build ingredient counts summary with icons
  Widget _buildIngredientsSummary(ThemeData theme) {
    final cheeseCount = widget.sandwich.cheeses.length;
    final proteinCount = widget.sandwich.proteins.length;
    final vegetableCount = widget.sandwich.vegetables.length;

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
            '$cheeseCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Protein count
        if (proteinCount > 0) ...[
          Icon(
            Icons.restaurant_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '$proteinCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (vegetableCount > 0) const SizedBox(width: 10),
        ],
        // Vegetable count
        if (vegetableCount > 0) ...[
          Icon(
            Icons.eco_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '$vegetableCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
