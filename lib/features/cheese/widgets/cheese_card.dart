import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/integrity_service.dart';
import '../../recipes/models/cuisine.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/memoix_card_shell.dart';
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MemoixCardShell(
      onTap: widget.onTap,
      isCompact: widget.isCompact,
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
                  // Buy indicator (styled like selected filter chip with secondary outline)
                  if (widget.entry.buy)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text('Buy'),
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: theme.colorScheme.secondary),
                        side: BorderSide(color: theme.colorScheme.secondary),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  // Favourite button
                  IconButton(
                    icon: Icon(
                      widget.entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: widget.entry.isFavorite
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      await ref.read(cheeseRepositoryProvider).toggleFavourite(widget.entry);
                      await processIntegrityResponses(ref);
                    },
                    padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  Widget _buildMetadataRow(ThemeData theme) {
    final hasCountry = widget.entry.country != null && widget.entry.country!.isNotEmpty;
    final hasMilk = widget.entry.milk != null && widget.entry.milk!.isNotEmpty;

    if (!hasCountry && !hasMilk) {
      return const SizedBox.shrink();
    }

    // Format: Milk type (Country adjective) - e.g., "Goat (Canadian)"
    return Row(
      children: [
        // Colored dot based on country
        if (hasCountry || hasMilk) ...[
          Text(
            '\u2022',
            style: TextStyle(
              color: hasCountry 
                  ? MemoixColors.forContinentDot(widget.entry.country)
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Milk type first
        if (hasMilk)
          Text(
            _capitalize(widget.entry.milk!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        // Country in brackets
        if (hasCountry) ...[
          Text(
            hasMilk ? ' (' : '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            Cuisine.toAdjective(widget.entry.country!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasMilk)
            Text(
              ')',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  /// Capitalizes the first letter of each word
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
