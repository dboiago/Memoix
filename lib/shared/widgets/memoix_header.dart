import 'dart:io';
import 'package:flutter/material.dart';

/// A unified header widget for all detail views across all cuisines.
///
/// This widget is model-agnostic - it accepts primitive values instead of
/// specific model types, allowing it to be used by Recipe, Modernist, Pizza,
/// Sandwich, Smoking, Cellar, and Cheese detail screens.
///
/// The header displays:
/// - Back button
/// - Title (scales down to fit, never wraps)
/// - Favorite button
/// - "I made this" button (optional)
/// - Share button (optional)
/// - Action menu (Edit, Duplicate, Delete)
///
/// Metadata chips and other content belong in the scrollable content area
/// below the header, not inside it.
class MemoixHeader extends StatelessWidget {
  const MemoixHeader({
    super.key,
    required this.title,
    this.isFavorite = false,
    this.headerImage,
    this.onFavoritePressed,
    this.onLogCookPressed,
    this.onSharePressed,
    this.onEditPressed,
    this.onDuplicatePressed,
    this.onDeletePressed,
  });

  /// The title to display in the header.
  final String title;

  /// Whether this item is marked as favorite.
  final bool isFavorite;

  /// Optional header image URL or file path.
  final String? headerImage;

  /// Callback when favorite button is pressed.
  final VoidCallback? onFavoritePressed;

  /// Callback when "I made this" button is pressed.
  final VoidCallback? onLogCookPressed;

  /// Callback when share button is pressed.
  final VoidCallback? onSharePressed;

  /// Callback when edit is selected from menu.
  final VoidCallback? onEditPressed;

  /// Callback when duplicate is selected from menu.
  final VoidCallback? onDuplicatePressed;

  /// Callback when delete is selected from menu.
  final VoidCallback? onDeletePressed;

  bool get _hasHeaderImage => headerImage != null && headerImage!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Scale font size with screen width: 20px at 320, up to 28px at 1200+
    final baseFontSize = (screenWidth / 40).clamp(20.0, 28.0);

    // Title color: primary (accent) when no image, muted when over image
    final titleColor = _hasHeaderImage
        ? theme.colorScheme.onSurfaceVariant // muted color over image
        : theme.colorScheme.primary; // accent color when no image

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
                  // Row 1: Back button (Left) + Action Icons (Right)
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
                          color: titleColor,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.7), offset: const Offset(0, 1))],
                        ),
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
    // Icon color: muted when over image, onSurface when no image
    final iconColor = _hasHeaderImage
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    final iconShadows = _hasHeaderImage
        ? [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.7), offset: const Offset(0, 1))]
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor, shadows: iconShadows),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Action icons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFavoritePressed != null)
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? theme.colorScheme.secondary : iconColor,
                  shadows: iconShadows,
                ),
                onPressed: onFavoritePressed,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            if (onLogCookPressed != null)
              IconButton(
                icon: Icon(Icons.check_circle_outline, color: iconColor, shadows: iconShadows),
                tooltip: 'I made this',
                onPressed: onLogCookPressed,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            if (onSharePressed != null)
              IconButton(
                icon: Icon(Icons.share, color: iconColor, shadows: iconShadows),
                onPressed: onSharePressed,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            if (onEditPressed != null || onDuplicatePressed != null || onDeletePressed != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEditPressed?.call();
                      break;
                    case 'duplicate':
                      onDuplicatePressed?.call();
                      break;
                    case 'delete':
                      onDeletePressed?.call();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (onEditPressed != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onDuplicatePressed != null)
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  if (onDeletePressed != null)
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
          ],
        ),
      ],
    );
  }
}
