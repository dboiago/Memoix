import 'dart:io';
import 'package:flutter/material.dart';

/// A unified header widget for all detail views across all cuisines.
///
/// This widget is model-agnostic - it accepts primitive values instead of
/// specific model types, allowing it to be used by Recipe, Modernist, Pizza,
/// Sandwich, Smoking, Cellar, and Cheese detail screens.
///
/// Supports two metadata display modes:
/// - `useChipMetadata: true` → Chips (for normal scrolling views)
/// - `useChipMetadata: false` → Compact text row (for side-by-side views)
///
/// The header automatically adjusts colors and shadows based on whether
/// an image is present.
class MemoixHeader extends StatelessWidget {
  const MemoixHeader({
    super.key,
    required this.title,
    this.isFavorite = false,
    this.useChipMetadata = true,
    this.headerImage,
    this.onBack,
    this.onToggleFavorite,
    this.onLogCook,
    this.onShare,
    this.onMenuSelected,
    this.metadataChips,
    this.compactMetadata,
    this.pairedRecipeChips,
  });

  /// The title to display in the header.
  final String title;

  /// Whether this item is marked as favorite.
  final bool isFavorite;

  /// Whether to display metadata as chips (true) or compact widget (false).
  final bool useChipMetadata;

  /// Optional header image URL or file path.
  final String? headerImage;

  /// Optional callback when back button is pressed.
  /// Defaults to Navigator.pop() if not provided.
  final VoidCallback? onBack;

  /// Callback when favorite button is pressed.
  final VoidCallback? onToggleFavorite;

  /// Callback when "I made this" / "Log" button is pressed.
  /// If null, the button is not shown.
  final VoidCallback? onLogCook;

  /// Callback when share button is pressed.
  /// If null, the button is not shown.
  final VoidCallback? onShare;

  /// Callback when a menu item is selected (edit, duplicate, delete).
  /// If null, the menu is not shown.
  final void Function(String value)? onMenuSelected;

  /// Widget to display as chips metadata (for useChipMetadata: true).
  /// Caller provides the actual chip widgets.
  final Widget? metadataChips;

  /// Widget to display as compact metadata (for useChipMetadata: false).
  /// Caller provides a Text.rich or similar widget.
  final Widget? compactMetadata;

  /// Optional widget list of paired recipe chips to display.
  final List<Widget>? pairedRecipeChips;

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
                        title,
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

                  // Row 3: Metadata (chips or compact widget)
                  if ((useChipMetadata && metadataChips != null) ||
                      (!useChipMetadata && compactMetadata != null))
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
                      child: useChipMetadata ? metadataChips! : compactMetadata!,
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

    // Build action buttons list
    final actionButtons = <Widget>[
      if (onToggleFavorite != null)
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? theme.colorScheme.primary : iconColor,
            shadows: iconShadows,
          ),
          onPressed: onToggleFavorite,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      if (onLogCook != null)
        IconButton(
          icon: Icon(Icons.check_circle_outline, color: iconColor, shadows: iconShadows),
          tooltip: 'I made this',
          onPressed: onLogCook,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      if (onShare != null)
        IconButton(
          icon: Icon(Icons.share, color: iconColor, shadows: iconShadows),
          onPressed: onShare,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
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
          padding: EdgeInsets.zero,
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor, shadows: iconShadows),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        // Action icons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: actionButtons,
        ),
      ],
    );
  }
}
