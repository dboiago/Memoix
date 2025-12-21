import 'package:flutter/material.dart';

/// Unified empty state widget for consistent "no items found" experience.
/// 
/// Uses the Memoix filled mark (knife+fork) as the visual element,
/// tinted to match the current theme's muted color.
/// 
/// Usage:
/// ```dart
/// MemoixEmptyState(
///   message: 'No recipes found',
/// )
/// ```
class MemoixEmptyState extends StatelessWidget {
  /// The message to display (e.g., "No recipes found")
  final String message;
  
  /// Optional subtitle for additional context
  final String? subtitle;
  
  /// Size of the mark image (default 64×64 to match previous icon size)
  final double markSize;

  const MemoixEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.markSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                theme.colorScheme.outline,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/images/Memoix-markfilled-black-512.png',
                width: markSize,
                height: markSize,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
