import 'dart:io';
import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/theme.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../models/spirit.dart';

/// A unified header widget for all recipe detail views.
///
/// Supports two metadata display modes:
/// - `useChipMetadata: true` → Chips (for normal scrolling views)
/// - `useChipMetadata: false` → Compact text row (for side-by-side views)
///
/// The header automatically adjusts colors and shadows based on whether
/// an image is present.
class RecipeHeader extends StatelessWidget {
  const RecipeHeader({
    super.key,
    required this.recipe,
    this.useChipMetadata = true,
    this.onBack,
    this.onToggleFavorite,
    this.onLogCook,
    this.onShare,
    this.onMenuSelected,
    this.pairedRecipeChips,
    this.headerImage,
  });

  /// The recipe to display in the header.
  final Recipe recipe;

  /// Whether to display metadata as chips (true) or compact text row (false).
  final bool useChipMetadata;

  /// Optional callback when back button is pressed.
  /// Defaults to Navigator.pop() if not provided.
  final VoidCallback? onBack;

  /// Callback when favorite button is pressed.
  final VoidCallback? onToggleFavorite;

  /// Callback when "I made this" button is pressed.
  final VoidCallback? onLogCook;

  /// Callback when share button is pressed.
  final VoidCallback? onShare;

  /// Callback when a menu item is selected (edit, duplicate, delete).
  final void Function(String value)? onMenuSelected;

  /// Optional widget list of paired recipe chips to display.
  final List<Widget>? pairedRecipeChips;

  /// Optional header image URL or file path.
  final String? headerImage;

  bool get _hasHeaderImage => headerImage != null && headerImage!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Scale font size with screen width: 20px at 320, up to 28px at 1200+
    final baseFontSize = (screenWidth / 40).clamp(20.0, 28.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        image: _hasHeaderImage
            ? DecorationImage(
                image: headerImage!.startsWith('http')
                    ? NetworkImage(headerImage!) as ImageProvider
                    : FileImage(File(headerImage!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          // Semi-transparent overlay for text legibility when image is present
          if (_hasHeaderImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),

          // Content inside SafeArea
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Navigation Icon (Left) + Action Icons (Right)
                  _buildActionRow(context, theme),

                  // Row 2: Title (scales down to fit, never wraps or truncates)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        recipe.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: baseFontSize,
                          color: _hasHeaderImage
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                          shadows: _hasHeaderImage
                              ? [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.7), offset: const Offset(0, 1))]
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Row 3: Metadata (chips or compact text row)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
                    child: useChipMetadata
                        ? _buildChipMetadata(context, theme)
                        : _buildCompactMetadataRow(theme),
                  ),

                  // Row 4: Paired recipes chips (if any) - right-aligned
                  if (pairedRecipeChips != null && pairedRecipeChips!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 6.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: pairedRecipeChips!,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the navigation and action icons row.
  Widget _buildActionRow(BuildContext context, ThemeData theme) {
    final iconColor = _hasHeaderImage
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    
    // Use shadow for icons when over an image
    final iconShadows = _hasHeaderImage
        ? [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.7), offset: const Offset(0, 1))]
        : null;

    return Row(
      children: [
        // Back button
        IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor, shadows: iconShadows),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        // Spacer to push actions to right
        const Spacer(),
        // Action icons - use Flexible to prevent overflow
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Favorite
            if (onToggleFavorite != null)
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.primary : iconColor,
                  shadows: iconShadows,
                ),
                onPressed: onToggleFavorite,
              ),
            // Log cook
            if (onLogCook != null)
              IconButton(
                icon: Icon(Icons.check_circle_outline, color: iconColor, shadows: iconShadows),
                tooltip: 'I made this',
                onPressed: onLogCook,
              ),
            // Share
            if (onShare != null)
              IconButton(
                icon: Icon(Icons.share, color: iconColor, shadows: iconShadows),
                onPressed: onShare,
              ),
              // Menu
              if (onMenuSelected != null)
                PopupMenuButton<String>(
                  onSelected: onMenuSelected,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert, color: iconColor, shadows: iconShadows),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build chip-style metadata (for normal scrolling views).
  Widget _buildChipMetadata(BuildContext context, ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final chipFontSize = isCompact ? 11.0 : 12.0;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Cuisine chip
        if (recipe.cuisine != null)
          Chip(
            label: Text(Cuisine.toAdjective(recipe.cuisine)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        // Pickle method chip
        if (recipe.course == 'pickles' &&
            recipe.pickleMethod != null &&
            recipe.pickleMethod!.isNotEmpty)
          Chip(
            label: Text(recipe.pickleMethod!),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        // Serves chip
        if (recipe.serves != null && recipe.serves!.isNotEmpty)
          Chip(
            avatar: Icon(Icons.people, size: 12, color: theme.colorScheme.onSurface),
            label: Text(_formatServes(recipe.serves!)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        // Time chip
        if (recipe.time != null && recipe.time!.isNotEmpty)
          Chip(
            avatar: Icon(Icons.timer, size: 12, color: theme.colorScheme.onSurface),
            label: Text(UnitNormalizer.normalizeTime(recipe.time!)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: chipFontSize,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  /// Build compact text-based metadata row (for side-by-side views).
  Widget _buildCompactMetadataRow(ThemeData theme) {
    final textColor = _hasHeaderImage
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurfaceVariant;
    final metadataItems = <InlineSpan>[];

    // Check if this is a drink (course == 'drinks')
    final isDrink = recipe.course?.toLowerCase() == 'drinks';

    if (isDrink) {
      // For drinks: show spirit dot + "Spirit (Cuisine)" like list view
      if (recipe.subcategory != null && recipe.subcategory!.isNotEmpty) {
        final spiritColor = MemoixColors.forSpiritDot(recipe.subcategory);
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: spiritColor,
              shape: BoxShape.circle,
            ),
          ),
        ));
        // Display spirit with optional cuisine origin
        final spirit = Spirit.toDisplayName(recipe.subcategory!);
        if (recipe.cuisine != null && recipe.cuisine!.isNotEmpty) {
          final cuisineAdj = Cuisine.toAdjective(recipe.cuisine);
          metadataItems.add(TextSpan(text: '$spirit ($cuisineAdj)'));
        } else {
          metadataItems.add(TextSpan(text: spirit));
        }
      } else if (recipe.cuisine != null) {
        // Fallback to cuisine for drinks without spirit
        final cuisineColor = MemoixColors.forContinentDot(recipe.cuisine);
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: cuisineColor,
              shape: BoxShape.circle,
            ),
          ),
        ));
        metadataItems.add(TextSpan(text: Cuisine.toAdjective(recipe.cuisine)));
      }
    } else {
      // For food recipes: show cuisine dot with cuisine name
      if (recipe.cuisine != null) {
        final cuisineColor = MemoixColors.forContinentDot(recipe.cuisine);
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: cuisineColor,
              shape: BoxShape.circle,
            ),
          ),
        ));
        metadataItems.add(TextSpan(text: Cuisine.toAdjective(recipe.cuisine)));
      }
    }

    // Add serves (normalized to just number with icon)
    if (recipe.serves != null && recipe.serves!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeServes(recipe.serves!);
      if (normalized.isNotEmpty) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.people, size: 12, color: textColor),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }

    // Add time (normalized to compact format with icon)
    if (recipe.time != null && recipe.time!.isNotEmpty) {
      final normalized = UnitNormalizer.normalizeTime(recipe.time!);
      if (normalized.isNotEmpty) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.schedule, size: 12, color: textColor),
        ));
        metadataItems.add(TextSpan(text: ' $normalized'));
      }
    }

    // Add glass for drinks (garnish is shown in ingredients, not header)
    final isDrinkCourse = recipe.course?.toLowerCase() == 'drinks';
    if (isDrinkCourse) {
      final hasGlass = recipe.glass != null && recipe.glass!.isNotEmpty;

      if (hasGlass) {
        if (metadataItems.isNotEmpty) {
          metadataItems.add(const TextSpan(text: '   '));
        }
        metadataItems.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.local_bar, size: 12, color: textColor),
        ));
        metadataItems.add(TextSpan(text: ' ${_capitalizeWords(recipe.glass!)}'));
      }
    }

    if (metadataItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
        ),
        children: metadataItems,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Format serves to just show the number.
  String _formatServes(String serves) {
    var result = serves
        .replaceAll(RegExp(r'\bserves?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bpeople\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bpersons?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bportions?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bservings?\b', caseSensitive: false), '')
        .trim();

    // Remove .0 decimals
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\.0(?=\D|$)'),
      (match) => match.group(1)!,
    );

    // Remove leading colons
    result = result.replaceFirst(RegExp(r'^:+\s*'), '');

    return result.trim();
  }

  /// Capitalize each word in a string (except common lowercase words).
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      final lower = word.toLowerCase();
      if (lower == 'of' ||
          lower == 'and' ||
          lower == 'or' ||
          lower == 'the' ||
          lower == 'a' ||
          lower == 'an' ||
          lower == 'to' ||
          lower == 'for' ||
          lower == 'with') {
        return lower;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
