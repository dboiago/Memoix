import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

/// Recipe rating widget (1-5 stars + favourite)
class RecipeRating extends StatelessWidget {
  final int rating; // 0-5 (0 = unrated)
  final bool isFavourite;
  final bool readOnly;
  final Function(int)? onRatingChanged;
  final Function(bool)? onFavouriteChanged;
  final double size;

  const RecipeRating({
    super.key,
    required this.rating,
    this.isFavourite = false,
    this.readOnly = false,
    this.onRatingChanged,
    this.onFavouriteChanged,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 5 stars
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          final isFilled = starNumber <= rating;

          return GestureDetector(
            onTap: readOnly ? null : () => onRatingChanged?.call(starNumber),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                isFilled ? Icons.star : Icons.star_border,
                color: isFilled ? MemoixColors.rating : theme.colorScheme.outline,
                size: size,
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        // Favourite heart
        GestureDetector(
          onTap: readOnly ? null : () => onFavouriteChanged?.call(!isFavourite),
          child: Icon(
            isFavourite ? Icons.favorite : Icons.favorite_border,
            color: isFavourite ? MemoixColors.favorite : theme.colorScheme.outline,
            size: size,
          ),
        ),
      ],
    );
  }
}

/// Compact rating display (for cards/lists)
class RecipeRatingCompact extends StatelessWidget {
  final int rating;
  final bool isFavourite;

  const RecipeRatingCompact({
    super.key,
    required this.rating,
    this.isFavourite = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rating > 0) ...[
          Icon(Icons.star, color: MemoixColors.rating, size: 16),
          const SizedBox(width: 2),
          Text(
            rating.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (isFavourite) ...[
          const SizedBox(width: 4),
          Icon(Icons.favorite, color: MemoixColors.favorite, size: 16),
        ],
      ],
    );
  }
}

/// "Made It" button with cook count
class MadeItButton extends StatelessWidget {
  final int cookCount;
  final DateTime? lastCooked;
  final bool isCompact;
  final VoidCallback? onPressed;

  const MadeItButton({
    super.key,
    required this.cookCount,
    this.lastCooked,
    this.isCompact = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: Text(
          cookCount > 0 ? 'Made $cookCount×' : 'Made It',
          style: const TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.check_circle_outline),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cookCount > 0 ? 'Made It ($cookCount times)' : 'Made It!'),
          if (lastCooked != null)
            Text(
              'Last: ${_formatDate(lastCooked!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cookCount > 0
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}

/// Quick rating dialog
class RateRecipeDialog extends StatefulWidget {
  final String recipeName;
  final int currentRating;
  final bool isFavourite;

  const RateRecipeDialog({
    super.key,
    required this.recipeName,
    this.currentRating = 0,
    this.isFavourite = false,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String recipeName,
    int currentRating = 0,
    bool isFavourite = false,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RateRecipeDialog(
        recipeName: recipeName,
        currentRating: currentRating,
        isFavourite: isFavourite,
      ),
    );
  }

  @override
  State<RateRecipeDialog> createState() => _RateRecipeDialogState();
}

class _RateRecipeDialogState extends State<RateRecipeDialog> {
  late int _rating;
  late bool _isFavourite;

  @override
  void initState() {
    super.initState();
    _rating = widget.currentRating;
    _isFavourite = widget.isFavourite;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Recipe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.recipeName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          RecipeRating(
            rating: _rating,
            isFavourite: _isFavourite,
            size: 36,
            onRatingChanged: (r) => setState(() => _rating = r),
            onFavouriteChanged: (f) => setState(() => _isFavourite = f),
          ),
          const SizedBox(height: 16),
          Text(
            _getRatingText(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'rating': _rating,
              'isFavourite': _isFavourite,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'Why';
      case 2:
        return 'Save';
      case 3:
        return 'If';
      case 4:
        return 'Its';
      case 5:
        return 'Shit';
      default:
        return 'Tap stars to rate';
    }
  }
}
