import 'package:flutter/material.dart';

/// Unified empty state widget for consistent "no items found" experience.
/// 
/// Usage:
/// ```dart
/// MemoixEmptyState(
///   message: 'No recipes found',
///   icon: Icons.restaurant,
/// )
/// ```
class MemoixEmptyState extends StatelessWidget {
  /// The message to display (e.g., "No recipes found")
  final String message;
  
  /// Optional icon to display above the message
  final IconData icon;
  
  /// Optional subtitle for additional context
  final String? subtitle;

  const MemoixEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.search_off,
    this.subtitle,
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
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.outline,
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
