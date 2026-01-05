import 'dart:async';
import 'package:flutter/material.dart';

/// A wrapper widget that implements the Gmail-style "inline undo" pattern.
/// 
/// When swiped to delete:
/// 1. The child content disappears
/// 2. A placeholder row with trash icon and UNDO button appears
/// 3. After [undoDuration] (or navigation away), the actual delete fires
/// 4. Tapping UNDO restores the item immediately
class InlineUndoWrapper extends StatefulWidget {
  /// The content to display when not in "pending delete" state
  final Widget child;

  /// Unique key for the Dismissible
  final Key dismissKey;

  /// Called when the delete is confirmed (after timer expires or navigation)
  final VoidCallback onDelete;

  /// Optional callback for left-to-right swipe action (non-destructive)
  /// If null, only right-to-left delete is enabled
  final VoidCallback? onSwipeAction;

  /// Icon to show during left-to-right swipe (if [onSwipeAction] is provided)
  final IconData? swipeActionIcon;

  /// Duration before the delete is finalized
  final Duration undoDuration;

  /// Height of the placeholder row (should match child height)
  final double? placeholderHeight;

  /// Optional name of the item for the placeholder text
  final String? itemName;

  const InlineUndoWrapper({
    super.key,
    required this.child,
    required this.dismissKey,
    required this.onDelete,
    this.onSwipeAction,
    this.swipeActionIcon,
    this.undoDuration = const Duration(seconds: 4),
    this.placeholderHeight,
    this.itemName,
  });

  @override
  State<InlineUndoWrapper> createState() => _InlineUndoWrapperState();
}

class _InlineUndoWrapperState extends State<InlineUndoWrapper> {
  bool _isPendingDelete = false;
  Timer? _deleteTimer;

  @override
  void dispose() {
    // If widget is disposed while pending delete, execute the delete
    if (_isPendingDelete) {
      widget.onDelete();
    }
    _deleteTimer?.cancel();
    super.dispose();
  }

  void _startDeleteTimer() {
    setState(() {
      _isPendingDelete = true;
    });
    
    _deleteTimer?.cancel();
    _deleteTimer = Timer(widget.undoDuration, () {
      if (mounted && _isPendingDelete) {
        widget.onDelete();
        // Don't reset state - let parent handle removal
      }
    });
  }

  void _undoDelete() {
    _deleteTimer?.cancel();
    setState(() {
      _isPendingDelete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show placeholder when pending delete
    if (_isPendingDelete) {
      return Container(
        height: widget.placeholderHeight ?? 72,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.itemName != null ? '${widget.itemName} deleted' : 'Deleted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: _undoDelete,
              child: Text(
                'UNDO',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    // Normal state: show dismissible child
    return Dismissible(
      key: widget.dismissKey,
      direction: widget.onSwipeAction != null
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      // Left-to-right background (if action provided)
      background: widget.onSwipeAction != null
          ? Container(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: Icon(
                widget.swipeActionIcon ?? Icons.check,
                color: theme.colorScheme.primary,
              ),
            )
          : Container(
              color: theme.colorScheme.secondary.withValues(alpha: 0.2),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.delete, color: theme.colorScheme.secondary),
            ),
      // Right-to-left background (delete)
      secondaryBackground: Container(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.secondary),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && widget.onSwipeAction != null) {
          // Left-to-right: perform action, don't dismiss
          widget.onSwipeAction!();
          return false;
        } else {
          // Right-to-left: start delete timer, show placeholder
          _startDeleteTimer();
          return false; // Don't actually dismiss - we show placeholder instead
        }
      },
      child: widget.child,
    );
  }
}

/// A simpler version for items within a list that manages its own pending state
/// This is useful when the parent needs to track which items are pending
class InlineUndoItem<T> {
  final T item;
  bool isPendingDelete;
  Timer? deleteTimer;

  InlineUndoItem({
    required this.item,
    this.isPendingDelete = false,
  });

  void startDeleteTimer(Duration duration, VoidCallback onDelete) {
    isPendingDelete = true;
    deleteTimer?.cancel();
    deleteTimer = Timer(duration, () {
      if (isPendingDelete) {
        onDelete();
      }
    });
  }

  void cancelDelete() {
    deleteTimer?.cancel();
    isPendingDelete = false;
  }

  void dispose() {
    deleteTimer?.cancel();
  }
}
