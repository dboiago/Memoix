import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../recipes/models/cuisine.dart';import '../models/cheese_entry.dart';
import '../repository/cheese_repository.dart';

/// Cheese entry card widget for list display
class CheeseCard extends ConsumerStatefulWidget {
  final CheeseEntry entry;
  final VoidCallback? onTap;
  final bool isCompact;

  const CheeseCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isCompact = false,
  });

  @override
  ConsumerState<CheeseCard> createState() => _CheeseCardState();
}

class _CheeseCardState extends ConsumerState<CheeseCard> {
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
              // Entry info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      widget.entry.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Only show metadata row in non-compact mode
                    if (!widget.isCompact) ...[
                      const SizedBox(height: 4),
                      _buildMetadataRow(theme),
                    ],
                  ],
                ),
              ),
              // Action icons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Buy indicator (styled like selected filter chip)
                  if (widget.entry.buy)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.secondary,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Buy',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      widget.entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: widget.entry.isFavorite
                        ? Colors.red.shade400
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      await ref.read(cheeseRepositoryProvider).toggleFavorite(widget.entry);
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

  Widget _buildMetadataRow(ThemeData theme) {
    final hasCountry = widget.entry.country != null && widget.entry.country!.isNotEmpty;
    final hasMilk = widget.entry.milk != null && widget.entry.milk!.isNotEmpty;

    if (!hasCountry && !hasMilk) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Colored dot for country (like cuisine dot in Mains)
        if (hasCountry) ...[
          Text(
            '\u2022',
            style: TextStyle(
              color: MemoixColors.forContinentDot(widget.entry.country),
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            Cuisine.toAdjective(widget.entry.country!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        // Milk type with icon
        if (hasMilk) ...[
          if (hasCountry) const SizedBox(width: 12),
          Icon(
            Icons.pets,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            widget.entry.milk!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
